const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {raiseOpsAlert} = require("./opsAlerts");

const RAW_COLLECTION = "ai_events";

const METRICS_COLLECTION = "ai_usage";
const SUMMARY_DOC = "summary";
const CONFIG_DOC = "config";

const DAILY_COLLECTION = "ai_usage_daily";

const AiFeature = Object.freeze({
  AI_SEARCH: "ai_search",
  ANALYZE_IMAGE: "analyze_image",
  ENHANCE_DESCRIPTION: "enhance_description",
  MODERATE_IMAGE: "moderate_image",
  CHATBOT: "chatbot",
  RECOMMENDATIONS: "recommendations",
  PHOTO_QUALITY: "photo_quality",
  ALERT_MATCH: "alert_match",
  CREATE_SMART_ALERT: "create_smart_alert",
  RETAIL_ESTIMATE: "retail_estimate_llm",
  BRAND_VERIFY: "brand_verify",
});

const FEATURE_VALUES = new Set(Object.keys(AiFeature).map((k) => AiFeature[k]));

const UNKNOWN_FEATURE = "unknown";

const AiOutcome = Object.freeze({
  OK: "ok",
  PROVIDER_ERROR: "provider_error",
  TIMEOUT: "timeout",
  RATE_LIMITED: "rate_limited",
  SAFETY_REFUSAL: "safety_refusal",
  PARSE_FAILURE: "parse_failure",
  SCHEMA_INVALID: "schema_invalid",
});

const OUTCOME_VALUES = Object.keys(AiOutcome).map((k) => AiOutcome[k]);
const OUTCOME_SET = new Set(OUTCOME_VALUES);

const ErrorKind = Object.freeze({
  TIMEOUT: "timeout",
  HTTP_429: "http_429",
  HTTP_4XX: "http_4xx",
  HTTP_5XX: "http_5xx",
  MODEL_NOT_FOUND: "model_not_found",
  NO_CONTENT: "no_content",
  NO_API_KEY: "no_api_key",
  NETWORK: "network",
  PROVIDER_REFUSAL: "provider_refusal",
  UNKNOWN: "unknown",
});

const WRITE_BUDGET_MS = 2000;

const RAW_RETENTION_DAYS = 90;

const SCAN_WINDOW_DAYS = 35;

const SUMMARY_WINDOWS = [7, 30];

const EVENT_PAGE = 500;
const MAX_EVENTS_SCANNED = 50000;
const PRUNE_PER_RUN = 500;

const MAX_SAMPLES_PER_DAY = 500;

const MIN_N_P50 = 5;
const MIN_N_P90 = 10;
const MIN_N_P95 = 20;

const MIN_N_RATE = 10;

const MAX_MODEL_LEN = 80;
const MAX_PROVIDER_LEN = 40;
const MAX_PROMPT_VERSION_LEN = 60;
const MAX_UID_LEN = 128;
const MAX_LOGGED_ERRORS = 8;
const MAX_ERROR_PATH_LEN = 60;
const MAX_ERROR_VALUE_LEN = 40;
const MAX_FAILED_PROVIDERS = 4;

const DAY_MS = 24 * 60 * 60 * 1000;

function dayKey(ms) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date(ms));
}

function tsFromNow(days) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + days * DAY_MS);
}

function finiteOrNull(v) {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function firstFinite(values) {
  for (const v of values) {
    const n = finiteOrNull(v);
    if (n !== null) return n;
  }
  return null;
}

function bounded(v, max) {
  if (typeof v !== "string") return null;
  const s = v.trim();
  if (!s) return null;
  return s.length > max ? s.slice(0, max) : s;
}

function nearestRank(sorted, p) {
  if (!sorted.length) return null;
  const rank = Math.ceil((p / 100) * sorted.length);
  return sorted[Math.min(Math.max(rank, 1), sorted.length) - 1];
}

function distribution(samples) {
  const s = samples.filter((x) => Number.isFinite(x) && x >= 0)
      .sort((a, b) => a - b);
  const n = s.length;
  return {
    n,
    p50: n >= MIN_N_P50 ? nearestRank(s, 50) : null,
    p90: n >= MIN_N_P90 ? nearestRank(s, 90) : null,
    p95: n >= MIN_N_P95 ? nearestRank(s, 95) : null,
    min: n ? s[0] : null,
    max: n ? s[n - 1] : null,
  };
}

function rate(num, den) {
  if (!den || den < MIN_N_RATE) return null;
  return num / den;
}

function capped(arr) {
  return arr.length > MAX_SAMPLES_PER_DAY ? arr.slice(0, MAX_SAMPLES_PER_DAY) : arr;
}

function normalizeFeature(feature) {
  if (typeof feature === "string" && FEATURE_VALUES.has(feature)) return feature;
  console.warn("⚠️ [AI_TELEMETRY] unknown feature name — add it to AiFeature:",
      bounded(feature, 40));
  return UNKNOWN_FEATURE;
}

function secondsToMs(sec) {
  const n = finiteOrNull(sec);
  return n === null ? null : Math.round(n * 1000);
}

function normalizeUsage(usage) {
  if (!usage || typeof usage !== "object") return null;
  const meta = (usage.usageMetadata && typeof usage.usageMetadata === "object") ?
      usage.usageMetadata : usage;

  const promptTokens = firstFinite([
    meta.prompt_tokens, meta.promptTokens, meta.promptTokenCount,
  ]);
  const completionTokens = firstFinite([
    meta.completion_tokens, meta.completionTokens, meta.candidatesTokenCount,
  ]);
  const totalTokens = firstFinite([
    meta.total_tokens, meta.totalTokens, meta.totalTokenCount,
  ]);

  const queueMs = firstFinite([secondsToMs(meta.queue_time), meta.queueMs]);
  const promptMs = firstFinite([secondsToMs(meta.prompt_time), meta.promptMs]);
  const completionMs =
      firstFinite([secondsToMs(meta.completion_time), meta.completionMs]);
  const providerTotalMs =
      firstFinite([secondsToMs(meta.total_time), meta.providerTotalMs]);

  const any = [promptTokens, completionTokens, totalTokens, queueMs, promptMs,
    completionMs, providerTotalMs].some((v) => v !== null);
  if (!any) return null;

  return {
    promptTokens,
    completionTokens,
    totalTokens: totalTokens !== null ? totalTokens :
      (promptTokens !== null && completionTokens !== null ?
        promptTokens + completionTokens : null),
    queueMs,
    promptMs,
    completionMs,
    providerTotalMs,
  };
}

function httpStatusFrom(error) {
  const direct = firstFinite([error && error.status, error && error.statusCode]);
  if (direct !== null && direct >= 100 && direct < 600) return direct;
  const message = String((error && error.message) || "");
  const m = /error:\s*(\d{3})\b/i.exec(message);
  return m ? Number(m[1]) : null;
}

function classifyError(error) {
  if (error && error.isSafetyRefusal === true) {
    return {
      outcome: AiOutcome.SAFETY_REFUSAL,
      errorKind: ErrorKind.PROVIDER_REFUSAL,
      httpStatus: null,
    };
  }

  const message = String((error && error.message) || "");
  const name = String((error && error.name) || "");
  const status = httpStatusFrom(error);

  if (name === "AbortError" || /timed out|ETIMEDOUT|ESOCKETTIMEDOUT/i.test(message)) {
    return {outcome: AiOutcome.TIMEOUT, errorKind: ErrorKind.TIMEOUT, httpStatus: status};
  }
  if (status === 429 || /resource-exhausted|rate.?limit|too many requests/i.test(message)) {
    return {outcome: AiOutcome.RATE_LIMITED, errorKind: ErrorKind.HTTP_429, httpStatus: status};
  }
  if (/model_not_found|no longer available|model.*(?:not found|does not exist)/i.test(message)) {
    return {
      outcome: AiOutcome.PROVIDER_ERROR,
      errorKind: ErrorKind.MODEL_NOT_FOUND,
      httpStatus: status,
    };
  }
  if (/returned no (?:message content|text part)/i.test(message)) {
    return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.NO_CONTENT, httpStatus: status};
  }
  if (/api key (?:not|is not) configured|missing api key/i.test(message)) {
    return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.NO_API_KEY, httpStatus: status};
  }
  if (/ECONNRESET|ENOTFOUND|EAI_AGAIN|ECONNREFUSED|socket hang up|fetch failed/i.test(message)) {
    return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.NETWORK, httpStatus: status};
  }
  if (status !== null && status >= 500) {
    return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.HTTP_5XX, httpStatus: status};
  }
  if (status !== null && status >= 400) {
    return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.HTTP_4XX, httpStatus: status};
  }
  return {outcome: AiOutcome.PROVIDER_ERROR, errorKind: ErrorKind.UNKNOWN, httpStatus: status};
}

function sanitizeErrors(errors) {
  if (!Array.isArray(errors)) return [];
  const out = [];
  for (const e of errors.slice(0, MAX_LOGGED_ERRORS)) {
    if (!e || typeof e !== "object") continue;
    const row = {
      path: bounded(e.path, MAX_ERROR_PATH_LEN) || "?",
      code: bounded(e.code, MAX_ERROR_PATH_LEN) || "invalid",
    };
    if (e.safe === true) {
      const got = bounded(e.got, MAX_ERROR_VALUE_LEN);
      if (got !== null) row.got = got;
    }
    out.push(row);
  }
  return out;
}

function withWriteBudget(promise) {
  let timer = null;
  const guarded = promise.then(() => true, (e) => {
    console.error("⚠️ [AI_TELEMETRY] event write failed:",
        e && e.message ? e.message : e);
    return false;
  });
  const budget = new Promise((resolve) => {
    timer = setTimeout(() => {
      console.warn("⚠️ [AI_TELEMETRY] event write exceeded its budget — dropping the row");
      resolve(false);
    }, WRITE_BUDGET_MS);
  });
  return Promise.race([guarded, budget]).then((ok) => {
    if (timer) clearTimeout(timer);
    return ok;
  });
}

function buildEventDoc(r) {
  const nowMs = Date.now();
  const usage = r.usage || {};
  return {
    feature: r.feature,
    outcome: r.outcome,
    provider: r.provider,
    model: r.model,
    firstProvider: r.firstProvider,
    fallbackUsed: r.provider !== null && r.firstProvider !== null &&
        r.provider !== r.firstProvider,
    failedProviders: r.failedProviders.slice(0, MAX_FAILED_PROVIDERS),
    attempts: r.attempts,

    latencyMs: r.latencyMs,
    queueMs: usage.queueMs === undefined ? null : usage.queueMs,
    promptMs: usage.promptMs === undefined ? null : usage.promptMs,
    completionMs: usage.completionMs === undefined ? null : usage.completionMs,
    providerTotalMs:
        usage.providerTotalMs === undefined ? null : usage.providerTotalMs,

    promptTokens: usage.promptTokens === undefined ? null : usage.promptTokens,
    completionTokens:
        usage.completionTokens === undefined ? null : usage.completionTokens,
    totalTokens: usage.totalTokens === undefined ? null : usage.totalTokens,

    cacheHit: r.cacheHit === true,

    errorKind: r.errorKind,
    httpStatus: r.httpStatus,
    failure: r.failure,

    promptVersion: r.promptVersion,

    uid: r.uid,
    day: dayKey(nowMs),
    at: admin.firestore.FieldValue.serverTimestamp(),
    atMs: nowMs,
    expiresAt: tsFromNow(RAW_RETENTION_DAYS),
  };
}

async function recordAiCall(params) {
  try {
    const p = params || {};
    const outcome = OUTCOME_SET.has(p.outcome) ? p.outcome : AiOutcome.OK;
    const failed = Array.isArray(p.failedProviders) ?
        p.failedProviders.map((x) => bounded(x, MAX_PROVIDER_LEN))
            .filter((x) => x !== null) : [];
    const errors = sanitizeErrors(p.errors);

    const doc = buildEventDoc({
      feature: normalizeFeature(p.feature),
      outcome,
      provider: bounded(p.provider, MAX_PROVIDER_LEN),
      model: bounded(p.model, MAX_MODEL_LEN),
      firstProvider: bounded(p.firstProvider, MAX_PROVIDER_LEN),
      failedProviders: failed,
      attempts: Math.max(1, Math.round(finiteOrNull(p.attempts) || 1)),
      latencyMs: finiteOrNull(p.latencyMs),
      usage: normalizeUsage(p.usage) || {},
      cacheHit: p.cacheHit === true,
      errorKind: bounded(p.errorKind, MAX_PROVIDER_LEN),
      httpStatus: finiteOrNull(p.httpStatus),
      failure: errors.length ? {errors} : null,
      promptVersion: bounded(p.promptVersion, MAX_PROMPT_VERSION_LEN),
      uid: bounded(p.uid, MAX_UID_LEN),
    });

    return await withWriteBudget(
        admin.firestore().collection(RAW_COLLECTION).add(doc));
  } catch (e) {
    console.error("⚠️ [AI_TELEMETRY] recordAiCall skipped:",
        e && e.message ? e.message : e);
    return false;
  }
}

function createSpan(r) {
  return {
    setProvider(provider, model) {
      r.provider = bounded(provider, MAX_PROVIDER_LEN);
      if (r.firstProvider === null) r.firstProvider = r.provider;
      if (model !== undefined) r.model = bounded(model, MAX_MODEL_LEN);
    },

    attempt(provider) {
      const name = bounded(provider, MAX_PROVIDER_LEN);
      if (r.firstProvider === null) r.firstProvider = name;
      r.attempts += 1;
    },

    providerFailed(provider) {
      const name = bounded(provider, MAX_PROVIDER_LEN);
      if (name && r.failedProviders.length < MAX_FAILED_PROVIDERS) {
        r.failedProviders.push(name);
      }
    },

    setUsage(usage) {
      const u = normalizeUsage(usage);
      if (u) r.usage = u;
    },

    setCacheHit() {
      r.cacheHit = true;
    },

    setPromptVersion(version) {
      r.promptVersion = bounded(version, MAX_PROMPT_VERSION_LEN);
    },

    setParseFailure(code) {
      r.outcome = AiOutcome.PARSE_FAILURE;
      r.errors = [{path: "$", code: bounded(code, MAX_ERROR_PATH_LEN) || "unparseable"}];
    },

    setSchemaInvalid(errors) {
      r.outcome = AiOutcome.SCHEMA_INVALID;
      r.errors = errors;
    },

    recordValidation(result) {
      if (!result || result.ok === true) return;
      if (result.stage === "parse" || result.stage === "empty") {
        r.outcome = AiOutcome.PARSE_FAILURE;
      } else {
        r.outcome = AiOutcome.SCHEMA_INVALID;
      }
      r.errors = result.errors;
    },
  };
}

async function runAiCall(spec, fn) {
  const s = spec || {};
  const startedAt = Date.now();
  const r = {
    feature: normalizeFeature(s.feature),
    outcome: AiOutcome.OK,
    provider: bounded(s.provider, MAX_PROVIDER_LEN),
    model: bounded(s.model, MAX_MODEL_LEN),
    firstProvider: bounded(s.provider, MAX_PROVIDER_LEN),
    failedProviders: [],
    attempts: 0,
    latencyMs: null,
    usage: null,
    cacheHit: false,
    errorKind: null,
    httpStatus: null,
    errors: null,
    promptVersion: bounded(s.promptVersion, MAX_PROMPT_VERSION_LEN),
    uid: bounded(s.uid, MAX_UID_LEN),
  };

  let span;
  try {
    span = createSpan(r);
  } catch (e) {
    console.error("⚠️ [AI_TELEMETRY] span construction failed:", e && e.message);
    return fn({
      setProvider() {}, attempt() {}, providerFailed() {}, setUsage() {},
      setCacheHit() {}, setPromptVersion() {}, setParseFailure() {},
      setSchemaInvalid() {}, recordValidation() {},
    });
  }

  try {
    const value = await fn(span);
    r.latencyMs = Date.now() - startedAt;
    await recordAiCall(r);
    return value;
  } catch (error) {
    r.latencyMs = Date.now() - startedAt;
    const cls = classifyError(error);
    if (r.outcome === AiOutcome.OK) r.outcome = cls.outcome;
    r.errorKind = cls.errorKind;
    r.httpStatus = cls.httpStatus;
    await recordAiCall(r);
    throw error;
  }
}

async function scanEvents(sinceMs, nowMs) {
  const db = admin.firestore();
  const events = [];
  let truncated = false;
  let cursor = null;

  for (;;) {
    let q = db.collection(RAW_COLLECTION)
        .where("atMs", ">=", sinceMs)
        .where("atMs", "<", nowMs)
        .orderBy("atMs")
        .limit(EVENT_PAGE);
    if (cursor) q = q.startAfter(cursor);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) events.push(doc.data() || {});

    cursor = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < EVENT_PAGE) break;
    if (events.length >= MAX_EVENTS_SCANNED) {
      truncated = true;
      break;
    }
  }
  return {events, truncated};
}

async function loadExclusionConfig() {
  try {
    const snap = await admin.firestore()
        .collection(METRICS_COLLECTION).doc(CONFIG_DOC).get();
    if (!snap.exists) return {excluded: new Set(), configured: false};
    const ids = (snap.data() || {}).excludedUserIds;
    if (!Array.isArray(ids)) return {excluded: new Set(), configured: false};
    return {
      excluded: new Set(ids.filter((x) => typeof x === "string" && x)),
      configured: true,
    };
  } catch (e) {
    console.error("⚠️ [AI_TELEMETRY] exclusion config read failed:", e.message);
    return {excluded: new Set(), configured: false};
  }
}

function newBucket() {
  const outcomes = {};
  for (const o of OUTCOME_VALUES) outcomes[o] = 0;
  return {
    calls: 0,
    outcomes,
    cacheHits: 0,
    fallbacks: 0,
    promptTokens: 0,
    completionTokens: 0,
    totalTokens: 0,
    tokensMeasured: 0,
    latencyMs: [],
    queueMs: [],
    byPromptVersion: new Map(),
  };
}

function addEvent(b, e) {
  b.calls += 1;

  const outcome = OUTCOME_SET.has(e.outcome) ? e.outcome : AiOutcome.PROVIDER_ERROR;
  b.outcomes[outcome] += 1;

  if (e.cacheHit === true) b.cacheHits += 1;
  if (e.fallbackUsed === true) b.fallbacks += 1;

  const total = finiteOrNull(e.totalTokens);
  const prompt = finiteOrNull(e.promptTokens);
  const completion = finiteOrNull(e.completionTokens);
  if (total !== null || prompt !== null || completion !== null) {
    b.tokensMeasured += 1;
    b.promptTokens += prompt || 0;
    b.completionTokens += completion || 0;
    b.totalTokens += total !== null ? total : (prompt || 0) + (completion || 0);
  }

  const latency = finiteOrNull(e.latencyMs);
  if (latency !== null && latency >= 0 && e.cacheHit !== true) {
    b.latencyMs.push(latency);
  }
  const queue = finiteOrNull(e.queueMs);
  if (queue !== null && queue >= 0) b.queueMs.push(queue);

  const version = typeof e.promptVersion === "string" && e.promptVersion ?
      e.promptVersion : "unversioned";
  let pv = b.byPromptVersion.get(version);
  if (!pv) {
    pv = {calls: 0, ok: 0, parseFailures: 0, schemaInvalid: 0, totalTokens: 0};
    b.byPromptVersion.set(version, pv);
  }
  pv.calls += 1;
  if (outcome === AiOutcome.OK) pv.ok += 1;
  if (outcome === AiOutcome.PARSE_FAILURE) pv.parseFailures += 1;
  if (outcome === AiOutcome.SCHEMA_INVALID) pv.schemaInvalid += 1;
  if (total !== null) pv.totalTokens += total;
}

function publishBucket(b) {
  const byPromptVersion = {};
  for (const [version, pv] of b.byPromptVersion) {
    byPromptVersion[version] = {
      calls: pv.calls,
      ok: pv.ok,
      parseFailures: pv.parseFailures,
      schemaInvalid: pv.schemaInvalid,
      totalTokens: pv.totalTokens,
      okRate: rate(pv.ok, pv.calls),
    };
  }

  const badShape = b.outcomes[AiOutcome.PARSE_FAILURE] +
      b.outcomes[AiOutcome.SCHEMA_INVALID];

  return {
    calls: b.calls,
    outcomes: {...b.outcomes},
    badShape: {
      count: badShape,
      rate: rate(badShape, b.calls),
    },
    okRate: rate(b.outcomes[AiOutcome.OK], b.calls),
    cacheHits: b.cacheHits,
    cacheHitRate: rate(b.cacheHits, b.calls),
    fallbacks: b.fallbacks,
    fallbackRate: rate(b.fallbacks, b.calls),
    tokens: {
      prompt: b.promptTokens,
      completion: b.completionTokens,
      total: b.totalTokens,
      measuredCalls: b.tokensMeasured,
      unmeasuredCalls: b.calls - b.tokensMeasured,
    },
    latencyMs: distribution(b.latencyMs),
    queueMs: distribution(b.queueMs),
    byPromptVersion,
  };
}

function bucketFor(map, key) {
  let b = map.get(key);
  if (!b) {
    b = newBucket();
    map.set(key, b);
  }
  return b;
}

function innerMapFor(map, key) {
  let inner = map.get(key);
  if (!inner) {
    inner = new Map();
    map.set(key, inner);
  }
  return inner;
}

function publishFeatures(map) {
  const out = {};
  for (const [feature, b] of map) out[feature] = publishBucket(b);
  return out;
}

async function computeAiUsageMetrics(nowMs = Date.now()) {
  const db = admin.firestore();
  const sinceMs = nowMs - SCAN_WINDOW_DAYS * DAY_MS;

  const [{excluded, configured}, scan] = await Promise.all([
    loadExclusionConfig(),
    scanEvents(sinceMs, nowMs),
  ]);
  const {events, truncated} = scan;

  const dayOverall = new Map();
  const dayFeatures = new Map();
  const windowOverall = new Map();
  const windowFeatures = new Map();
  for (const w of SUMMARY_WINDOWS) {
    windowOverall.set(w, newBucket());
    windowFeatures.set(w, new Map());
  }

  let countedEvents = 0;
  let excludedEvents = 0;
  let earliestEventMs = null;

  for (const e of events) {
    const atMs = finiteOrNull(e.atMs);
    if (atMs === null) continue;
    if (typeof e.uid === "string" && excluded.has(e.uid)) {
      excludedEvents += 1;
      continue;
    }
    countedEvents += 1;
    if (earliestEventMs === null || atMs < earliestEventMs) earliestEventMs = atMs;

    const feature = typeof e.feature === "string" && e.feature ?
        e.feature : UNKNOWN_FEATURE;
    const key = dayKey(atMs);

    addEvent(bucketFor(dayOverall, key), e);
    addEvent(bucketFor(innerMapFor(dayFeatures, key), feature), e);

    for (const w of SUMMARY_WINDOWS) {
      if (atMs >= nowMs - w * DAY_MS) {
        addEvent(windowOverall.get(w), e);
        addEvent(bucketFor(windowFeatures.get(w), feature), e);
      }
    }
  }

  const windows = {};
  for (const w of SUMMARY_WINDOWS) {
    windows[`d${w}`] = {
      days: w,
      fromMs: nowMs - w * DAY_MS,
      overall: publishBucket(windowOverall.get(w)),
      features: publishFeatures(windowFeatures.get(w)),
    };
  }

  const summary = {
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
    computedAtMs: nowMs,
    scanWindowDays: SCAN_WINDOW_DAYS,
    scannedEvents: events.length,
    countedEvents,
    excludedEvents,
    testExclusionConfigured: configured,
    truncated,
    earliestEventMs: (earliestEventMs !== null &&
        earliestEventMs > sinceMs + DAY_MS) ? earliestEventMs : null,
    featureVocabulary: Object.keys(AiFeature).map((k) => AiFeature[k]),
    outcomeVocabulary: OUTCOME_VALUES,
    windows,
  };

  const batch = db.batch();
  batch.set(db.collection(METRICS_COLLECTION).doc(SUMMARY_DOC), summary);
  for (const [key, b] of dayOverall) {
    batch.set(db.collection(DAILY_COLLECTION).doc(key), {
      date: key,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
      overall: publishBucket(b),
      features: publishFeatures(dayFeatures.get(key) || new Map()),
      samples: {
        latencyMs: capped(b.latencyMs),
      },
    });
  }
  await batch.commit();

  console.log(
      `🤖 [AI_TELEMETRY] ${events.length} event(s) scanned, ` +
      `${countedEvents} counted, ${excludedEvents} excluded, ` +
      `${dayOverall.size} day doc(s)${truncated ? " [TRUNCATED]" : ""}`);

  if (truncated) {
    await raiseOpsAlert({
      type: "ai_usage_scan_truncated",
      entityId: "aiTelemetry",
      severity: "WARNING",
      message: `AI usage scan hit ${MAX_EVENTS_SCANNED} events — ` +
        "the published window is partial",
      context: {scanWindowDays: SCAN_WINDOW_DAYS},
    });
  }

  return summary;
}

async function pruneExpiredEvents() {
  try {
    const db = admin.firestore();
    const snap = await db.collection(RAW_COLLECTION)
        .where("expiresAt", "<=", admin.firestore.Timestamp.now())
        .limit(PRUNE_PER_RUN)
        .get();
    if (snap.empty) return 0;
    const batch = db.batch();
    for (const doc of snap.docs) batch.delete(doc.ref);
    await batch.commit();
    return snap.size;
  } catch (e) {
    console.error("⚠️ [AI_TELEMETRY] prune failed:", e.message);
    return 0;
  }
}

exports.rollupAiUsage = functions.pubsub
    .schedule("50 */6 * * *")
    .timeZone("Asia/Jerusalem")
    .onRun(async () => {
      try {
        await computeAiUsageMetrics();
      } catch (e) {
        console.error("❌ [AI_TELEMETRY] rollup failed:", e);
        await raiseOpsAlert({
          type: "ai_usage_rollup_failed",
          entityId: "aiTelemetry",
          severity: "WARNING",
          message: "AI usage rollup threw — the dashboard is showing stale data",
          context: {error: e.message || String(e)},
        });
      }
      const pruned = await pruneExpiredEvents();
      if (pruned > 0) console.log(`🧹 [AI_TELEMETRY] pruned ${pruned} expired event(s)`);
      return null;
    });

exports.recomputeAiUsage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  let ok = context.auth.token.admin === true;
  if (!ok) {
    try {
      const snap = await admin.firestore()
          .collection("users").doc(context.auth.uid).get();
      ok = snap.exists && (snap.data() || {}).role === "admin";
    } catch (e) {
      console.error("⚠️ [AI_TELEMETRY] admin role lookup failed:", e.message);
    }
  }
  if (!ok) {
    throw new functions.https.HttpsError(
        "permission-denied", "רק מנהל יכול לרענן את מדדי ה-AI.");
  }

  const summary = await computeAiUsageMetrics();
  return {
    ok: true,
    scannedEvents: summary.scannedEvents,
    countedEvents: summary.countedEvents,
    excludedEvents: summary.excludedEvents,
  };
});

exports.runAiCall = runAiCall;
exports.recordAiCall = recordAiCall;
exports.normalizeUsage = normalizeUsage;
exports.AiFeature = AiFeature;
exports.AiOutcome = AiOutcome;
exports.ErrorKind = ErrorKind;

exports.RAW_COLLECTION = RAW_COLLECTION;
exports.METRICS_COLLECTION = METRICS_COLLECTION;
exports.DAILY_COLLECTION = DAILY_COLLECTION;
exports.SUMMARY_DOC = SUMMARY_DOC;
exports.CONFIG_DOC = CONFIG_DOC;

exports.computeAiUsageMetrics = computeAiUsageMetrics;
exports.pruneExpiredEvents = pruneExpiredEvents;
exports._internals = {
  classifyError, sanitizeErrors, distribution, rate, dayKey, nearestRank,
  normalizeFeature, publishBucket, newBucket, addEvent,
  MIN_N_P50, MIN_N_P90, MIN_N_P95, MIN_N_RATE,
};
