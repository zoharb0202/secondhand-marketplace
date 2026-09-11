const admin = require('firebase-admin');

const SIGNAL_WEIGHTS = {
  view: 1,
  dwell: 2,
  like: 4,
  share: 6,
  addToCart: 8,
  chat: 12,
  offer: 16,
  purchase: 25,
};

const ATTENTION_SCALE = 3;

const DWELL_FULL_MS = 30000;

const DWELL_EVENT_CAP_MS = 120000;

const LIFETIME_WEIGHT = 0.5;

const TRENDING_WINDOW_DAYS = 7;

const RECENT_DAYS = 3;
const RECENT_DAY_WEIGHT = 2;

const TRENDING_HALF_LIFE_DAYS = 14;
const AGE_FLOOR = 0.5;

const SELLER_MAX_BOOST = 0.25;
const SELLER_RATING_FLOOR = 3.5;
const SELLER_MIN_REVIEWS = 3;
const SELLER_SALES_SATURATION = 50;
const SELLER_RECENT_SALES_SATURATION = 10;

const TREND_SCALE = 10;

function num(v) {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function nonNeg(v) {
  return Math.max(0, num(v));
}

function clamp01(v) {
  const n = num(v);
  if (n <= 0) return 0;
  return n > 1 ? 1 : n;
}

function localDateKey(date, daysAgo) {
  const d = new Date((date || new Date()).getTime() - (daysAgo || 0) * 86400000);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jerusalem',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(d);
}

function emptyCounts() {
  return {
    views: 0, likes: 0, carts: 0, chats: 0, offers: 0,
    shares: 0, purchases: 0, dwellMs: 0, dwells: 0,
  };
}

function windowCountsFrom(daysMap, opts) {
  const o = opts || {};
  const windowDays = o.windowDays || TRENDING_WINDOW_DAYS;
  const at = new Date(o.nowMs || Date.now());
  const keyFn = o.dateKeyFn || localDateKey;
  const out = emptyCounts();
  if (!daysMap || typeof daysMap !== 'object') return out;

  for (let i = 0; i < windowDays; i++) {
    const day = daysMap[keyFn(at, i)];
    if (!day || typeof day !== 'object') continue;
    const w = i < RECENT_DAYS ? RECENT_DAY_WEIGHT : 1;
    for (const k of Object.keys(out)) {
      out[k] += nonNeg(day[k]) * w;
    }
  }
  return out;
}

function dwellPointsOf(counts) {
  const c = counts || {};
  const events = nonNeg(c.dwells);
  if (events === 0) return 0;
  const fullReads = Math.min(events, nonNeg(c.dwellMs) / DWELL_FULL_MS);
  return SIGNAL_WEIGHTS.dwell * fullReads;
}

function attentionPointsOf(counts) {
  const c = counts || {};
  const raw = SIGNAL_WEIGHTS.view * nonNeg(c.views) + dwellPointsOf(c);
  return ATTENTION_SCALE * Math.log1p(raw);
}

function intentPointsOf(counts) {
  const c = counts || {};
  return SIGNAL_WEIGHTS.like * nonNeg(c.likes) +
    SIGNAL_WEIGHTS.share * nonNeg(c.shares) +
    SIGNAL_WEIGHTS.addToCart * nonNeg(c.carts) +
    SIGNAL_WEIGHTS.chat * nonNeg(c.chats) +
    SIGNAL_WEIGHTS.offer * nonNeg(c.offers) +
    SIGNAL_WEIGHTS.purchase * nonNeg(c.purchases);
}

function lifetimePointsOf(product) {
  const p = product || {};
  return LIFETIME_WEIGHT * Math.log1p(nonNeg(p.viewCount) + 5 * nonNeg(p.likeCount));
}

function ageFactorOf(ageDays) {
  const d = nonNeg(ageDays);
  return AGE_FLOOR + (1 - AGE_FLOOR) * Math.exp(-d / TRENDING_HALF_LIFE_DAYS);
}

function sellerStrengthOf(seller, recentSales) {
  const s = seller || {};
  const reviews = nonNeg(s.totalReviews);
  const rating = nonNeg(s.sellerRating);
  const ratingPart = reviews >= SELLER_MIN_REVIEWS ?
    clamp01((rating - SELLER_RATING_FLOOR) / (5 - SELLER_RATING_FLOOR)) : 0;
  const lifetimeSales = Math.max(
      nonNeg((s.stats || {}).totalSales), nonNeg(s.totalSales));
  const salesPart = clamp01(
      Math.log1p(lifetimeSales) / Math.log1p(SELLER_SALES_SATURATION));
  const recentPart = clamp01(
      Math.log1p(nonNeg(recentSales)) / Math.log1p(SELLER_RECENT_SALES_SATURATION));
  const verifiedPart = s.isSellerVerified === true ? 1 : 0;

  return clamp01(
      0.40 * ratingPart + 0.25 * salesPart + 0.20 * recentPart + 0.15 * verifiedPart);
}

function sellerBoostOf(seller, recentSales) {
  return 1 + SELLER_MAX_BOOST * sellerStrengthOf(seller, recentSales);
}

function trendScoreFor(args) {
  const a = args || {};
  const product = a.product || {};
  const nowMs = a.nowMs || Date.now();

  const counts = windowCountsFrom(
      (a.dailyStats || {}).days,
      {nowMs, dateKeyFn: a.dateKeyFn});

  const attention = attentionPointsOf(counts);
  const intent = intentPointsOf(counts);
  const lifetime = lifetimePointsOf(product);

  let createdMs = nowMs;
  if (product.createdAt && typeof product.createdAt.toMillis === 'function') {
    createdMs = product.createdAt.toMillis();
  } else if (product.createdAt instanceof Date) {
    createdMs = product.createdAt.getTime();
  }
  const ageDays = Math.max((nowMs - createdMs) / 86400000, 0);
  const ageFactor = ageFactorOf(ageDays);
  const sellerBoost = sellerBoostOf(a.seller, a.recentSellerSales);

  const raw = (attention + intent + lifetime) * ageFactor * sellerBoost;
  const score = Math.round(TREND_SCALE * Math.log1p(nonNeg(raw)) * 100) / 100;

  return {
    score: Number.isFinite(score) ? score : 0,
    attention, intent, lifetime, ageFactor, sellerBoost, counts,
  };
}

const SIGNAL_CURSOR_DOC_PATH = '_internal/trendingSignalsCursor';

const FIRST_RUN_LOOKBACK_DAYS = 7;

const ROLLUP_PAGE_SIZE = 2000;

const WRITE_BATCH_LIMIT = 400;

const POSITIVE_INTERACTIONS = {
  add_to_cart: 'carts',
  chat_started: 'chats',
  offer_made: 'offers',
  share: 'shares',
  purchase: 'purchases',
};

const NEGATIVE_INTERACTIONS = {
  remove_from_cart: 'carts',
};

function bumpDay(target, productId, dateKey, field, by) {
  if (!target.has(productId)) target.set(productId, {});
  const days = target.get(productId);
  if (!days[dateKey]) days[dateKey] = {};
  days[dateKey][field] = (days[dateKey][field] || 0) + by;
}

function newSignalAccumulator() {
  return {products: new Map(), sellers: new Map(), seen: new Set()};
}

function foldInteractionEvent(acc, docId, event, nowMs) {
  const e = event || {};
  const createdAt = e.createdAt;
  const eventMs = createdAt && typeof createdAt.toMillis === 'function' ?
    createdAt.toMillis() : nowMs;

  const type = e.type;
  const productId = e.productId;
  if (!type || typeof productId !== 'string' || !productId) return eventMs;

  const dateKey = localDateKey(new Date(eventMs), 0);

  if (type === 'dwell') {
    const ms = Math.min(nonNeg(e.dwellMs), DWELL_EVENT_CAP_MS);
    if (ms > 0) {
      bumpDay(acc.products, productId, dateKey, 'dwellMs', ms);
      bumpDay(acc.products, productId, dateKey, 'dwells', 1);
    }
    return eventMs;
  }

  const positive = POSITIVE_INTERACTIONS[type];
  const negative = NEGATIVE_INTERACTIONS[type];
  if (!positive && !negative) return eventMs;

  const actor = typeof e.userId === 'string' && e.userId ? e.userId : docId;
  const dedupKey = `${productId}|${actor}|${type}|${dateKey}`;
  if (acc.seen.has(dedupKey)) return eventMs;
  acc.seen.add(dedupKey);

  if (positive) {
    bumpDay(acc.products, productId, dateKey, positive, 1);
    if (type === 'purchase' && typeof e.sellerId === 'string' && e.sellerId) {
      bumpDay(acc.sellers, e.sellerId, dateKey, 'purchases', 1);
    }
  } else {
    bumpDay(acc.products, productId, dateKey, negative, -1);
  }
  return eventMs;
}

async function commitDayDeltas(db, collection, deltas, idField) {
  let written = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const [docId, days] of deltas.entries()) {
    const payload = {};
    for (const [dateKey, fields] of Object.entries(days)) {
      const dayPayload = {};
      for (const [field, delta] of Object.entries(fields)) {
        if (!delta) continue;
        dayPayload[field] = admin.firestore.FieldValue.increment(delta);
      }
      if (Object.keys(dayPayload).length > 0) payload[dateKey] = dayPayload;
    }
    if (Object.keys(payload).length === 0) continue;

    batch.set(db.collection(collection).doc(docId), {
      [idField]: docId,
      days: payload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    written++;
    inBatch++;

    if (inBatch >= WRITE_BATCH_LIMIT) {
      await batch.commit();
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) await batch.commit();
  return written;
}

async function runRollupInteractionSignals(db, opts) {
  const nowMs = (opts && opts.nowMs) || Date.now();
  const cursorRef = db.doc(SIGNAL_CURSOR_DOC_PATH);
  const cursorSnap = await cursorRef.get();
  const cursorData = cursorSnap.exists ? cursorSnap.data() : null;

  const hasCursor = !!(cursorData && cursorData.lastRunAt &&
    typeof cursorData.lastRunAt.toMillis === 'function');
  const sinceMs = hasCursor ?
    cursorData.lastRunAt.toMillis() :
    nowMs - FIRST_RUN_LOOKBACK_DAYS * 86400000;
  const sinceTs = admin.firestore.Timestamp.fromMillis(sinceMs);

  const acc = newSignalAccumulator();
  let scanned = 0;
  let latestEventMs = sinceMs;
  let lastDoc = null;

  for (;;) {
    let q = db.collection('user_interactions')
        .where('createdAt', '>', sinceTs)
        .orderBy('createdAt', 'asc')
        .limit(ROLLUP_PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const eventMs = foldInteractionEvent(acc, doc.id, doc.data() || {}, nowMs);
      latestEventMs = Math.max(latestEventMs, eventMs);
    }

    scanned += snap.docs.length;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < ROLLUP_PAGE_SIZE) break;
  }

  const productsTouched = await commitDayDeltas(
      db, 'product_daily_stats', acc.products, 'productId');
  const sellersTouched = await commitDayDeltas(
      db, 'seller_daily_stats', acc.sellers, 'sellerId');

  const nextCursorMs = scanned > 0 ? latestEventMs : nowMs;
  await cursorRef.set(
      {lastRunAt: admin.firestore.Timestamp.fromMillis(nextCursorMs)}, {merge: true});

  return {scanned, productsTouched, sellersTouched};
}

function makeSellerCache(db, opts) {
  const nowMs = (opts && opts.nowMs) || Date.now();
  const cache = new Map();

  return {
    async load(ids) {
      const missing = [...new Set(ids.filter((id) => typeof id === 'string' && id && !cache.has(id)))];
      if (missing.length === 0) return;

      const userRefs = missing.map((id) => db.collection('users').doc(id));
      const statRefs = missing.map((id) => db.collection('seller_daily_stats').doc(id));
      const [userSnaps, statSnaps] = await Promise.all([
        db.getAll(...userRefs),
        db.getAll(...statRefs),
      ]);

      missing.forEach((id, i) => {
        const user = userSnaps[i].exists ? (userSnaps[i].data() || {}) : {};
        const stats = statSnaps[i].exists ? (statSnaps[i].data() || {}) : {};
        const counts = windowCountsFrom(stats.days, {nowMs});
        cache.set(id, {seller: user, recentSales: counts.purchases});
      });
    },
    get(id) {
      return cache.get(id) || {seller: null, recentSales: 0};
    },
  };
}

module.exports = {
  SIGNAL_WEIGHTS,
  ATTENTION_SCALE,
  DWELL_FULL_MS,
  DWELL_EVENT_CAP_MS,
  LIFETIME_WEIGHT,
  TRENDING_WINDOW_DAYS,
  RECENT_DAYS,
  RECENT_DAY_WEIGHT,
  TRENDING_HALF_LIFE_DAYS,
  AGE_FLOOR,
  SELLER_MAX_BOOST,
  SELLER_RATING_FLOOR,
  SELLER_MIN_REVIEWS,
  SELLER_SALES_SATURATION,
  SELLER_RECENT_SALES_SATURATION,
  TREND_SCALE,
  SIGNAL_CURSOR_DOC_PATH,
  POSITIVE_INTERACTIONS,
  NEGATIVE_INTERACTIONS,
  localDateKey,
  emptyCounts,
  windowCountsFrom,
  dwellPointsOf,
  attentionPointsOf,
  intentPointsOf,
  lifetimePointsOf,
  ageFactorOf,
  sellerStrengthOf,
  sellerBoostOf,
  trendScoreFor,
  newSignalAccumulator,
  foldInteractionEvent,
  runRollupInteractionSignals,
  makeSellerCache,
};
