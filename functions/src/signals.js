const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const {checkRateLimit} = require('./optimizations');

const RAW = 'signal_events';

const KIND = {
  LISTING: 'listing',
  SEARCH: 'search',
  CLICK: 'search_click',
  SALE: 'sale',
};

const RAW_RETENTION_DAYS = 45;
const PENDING_LISTING_TTL_DAYS = 7;
const LISTING_RETENTION_DAYS = 400;
const PRUNE_PER_RUN = 500;

const MIN_COMPARABLE_SALES = 5;
const SALE_WINDOW_DAYS = 365;
const PRICE_SAMPLES_CAP = 60;

const RETAIL_VALUE_FIELD = 'retailEstimate';

const SYNONYM_MIN_USERS = 3;
const SYNONYM_MIN_USERS_KTIV = 2;
const SYNONYM_CHAIN_WINDOW_MS = 10 * 60 * 1000;
const SYNONYM_MAX_PUBLISHED = 400;
const SYNONYM_MAX_EXPANSIONS = 8;
const SYNONYM_CACHE_MS = 10 * 60 * 1000;

const DEMAND_MIN_USERS = 3;
const DEMAND_WINDOW_DAYS = 30;
const DEMAND_RECENT_DAYS = 7;
const DEMAND_USERS_PER_DAY_CAP = 200;

function localDateKey(date, daysAgo) {
  const d = new Date((date || new Date()).getTime() - (daysAgo || 0) * 86400000);
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Jerusalem',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(d);
}

function daysBetweenKeys(a, b) {
  const ms = Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`);
  return Math.round(ms / 86400000);
}

function userKey(uid) {
  return crypto.createHash('sha256')
      .update(`marketplace-signals-v1|${String(uid || '')}`)
      .digest('hex').slice(0, 20);
}

function tsFromNow(days) {
  return admin.firestore.Timestamp.fromMillis(Date.now() + days * 86400000);
}

const HEB_DIACRITICS = /[֑-ׇ]/g;
const HEB_QUOTES = /['"׳״‘’“”]/g;
const FINAL_FORMS = {'ך': 'כ', 'ם': 'מ', 'ן': 'נ',
  'ף': 'פ', 'ץ': 'צ'};
const NON_WORD = /[^0-9a-zא-ת]+/;

function normalizeToken(raw) {
  let t = String(raw || '').toLowerCase().trim();
  t = t.replace(HEB_DIACRITICS, '').replace(HEB_QUOTES, '');
  t = t.replace(/[ךםןףץ]/g, (c) => FINAL_FORMS[c] || c);
  t = t.replace(/וו/g, 'ו').replace(/יי/g, 'י');
  return t;
}

function looseKey(raw) {
  return normalizeToken(raw).replace(/[וי]/g, '');
}

const LOOSE_MIN_LEN = 4;

const STOPWORDS = new Set([
  'של', 'עם', 'על', 'את', 'אני', 'מה', 'זה', 'יש', 'כל', 'גם', 'או', 'אם',
  'עד', 'אבל', 'הכי', 'בשביל', 'למכירה', 'מחפש', 'מחפשת', 'דרוש', 'דרושה',
  'מחיר', 'זול', 'זולה', 'בזול', 'שח', 'שקל', 'שקלים', 'ils',
  'the', 'for', 'and', 'with',
]);

function tokenize(text) {
  const out = [];
  const seen = new Set();
  for (const part of normalizeToken(text).split(NON_WORD)) {
    if (part.length < 2) continue;
    if (STOPWORDS.has(part)) continue;
    if (seen.has(part)) continue;
    seen.add(part);
    out.push(part);
  }
  return out;
}

function retailEstimateKey(parts) {
  const material = [
    parts.category, parts.subcategory, parts.brand, parts.model,
  ].map((v) => normalizeToken(String(v || '')).replace(/\s+/g, '')).join('|');
  return crypto.createHash('sha256')
      .update(`retail_v1|${material}`).digest('hex').slice(0, 32);
}

function productModelRaw(product) {
  return String((product && product.specificFields &&
      product.specificFields.model) || (product && product.model) || '');
}

function priceKeyPartsFor(product) {
  const brand = normalizeToken(product.brand || '');
  const model = normalizeToken(productModelRaw(product));
  const category = product.categoryId || product.category || '';
  const subcategory = product.subCategoryId || product.subcategory || '';
  if (!brand) return null;
  if (!model && !subcategory) return null;
  return {category, subcategory, brand, model};
}

function isSeedProduct(product) {
  return !!(product && product.testBatch);
}

async function writeEvent(docId, payload) {
  try {
    const day = localDateKey(new Date(), 0);
    const {ttlDays, ...body} = payload;
    await admin.firestore().collection(RAW).doc(docId).create({
      ...body,
      day,
      kindDay: `${payload.kind}|${day}`,
      at: admin.firestore.FieldValue.serverTimestamp(),
      atMs: Date.now(),
      expiresAt: tsFromNow(ttlDays || RAW_RETENTION_DAYS),
    });
    return true;
  } catch (e) {
    if (e && (e.code === 6 || e.code === 'already-exists')) return false;
    console.error('⚠️ [SIGNALS] writeEvent failed:', e.message);
    return false;
  }
}

const SEED_SYNONYMS = [
  ['מקרר', 'פריגידר'],
  ['סלולרי', 'פלאפון'], ['סלולרי', 'נייד'], ['פלאפון', 'נייד'],
  ['סלולרי', 'סמארטפון'], ['טלפון', 'סמארטפון'],
  ['אייפון', 'איפון'], ['אייפון', 'iphone'], ['איפון', 'iphone'],
  ['סמסונג', 'samsung'], ['גלקסי', 'galaxy'],
  ['מקבוק', 'macbook'], ['לפטופ', 'laptop'], ['לפטופ', 'נייד'],
  ['טלויזיה', 'טלוזיה'], ['טלויזיה', 'tv'],
  ['אופניים', 'אפניים'], ['קורקינט', 'סקוטר'],
  ['ספה', 'סלון'], ['מזגן', 'מיזוג'],
  ['נייקי', 'nike'], ['אדידס', 'adidas'],
  ['שואב', 'רומבה'], ['מייבש', 'מיבש'],
  ['פלייסטיישן', 'ps5'], ['פלייסטיישן', 'playstation'],
  ['אוזניות', 'איירפודס'], ['אוזניות', 'airpods'],
];

const SEED_MAP = (() => {
  const m = new Map();
  const add = (a, b) => {
    const ka = normalizeToken(a);
    const kb = normalizeToken(b);
    if (!m.has(ka)) m.set(ka, new Set());
    m.get(ka).add(kb);
  };
  for (const [a, b] of SEED_SYNONYMS) {
    add(a, b);
    add(b, a);
  }
  return m;
})();

const SEED_CANONICAL = (() => {
  const parent = new Map();
  const find = (x) => {
    if (!parent.has(x)) parent.set(x, x);
    while (parent.get(x) !== x) {
      parent.set(x, parent.get(parent.get(x)));
      x = parent.get(x);
    }
    return x;
  };
  const union = (a, b) => {
    const ra = find(a);
    const rb = find(b);
    if (ra === rb) return;
    if (ra < rb) parent.set(rb, ra);
    else parent.set(ra, rb);
  };
  for (const [a, b] of SEED_SYNONYMS) {
    union(normalizeToken(a), normalizeToken(b));
  }
  const out = new Map();
  for (const k of parent.keys()) out.set(k, find(k));
  return out;
})();

let _learnedCache = {at: 0, map: new Map()};

async function loadLearnedSynonyms() {
  if (Date.now() - _learnedCache.at < SYNONYM_CACHE_MS) return _learnedCache.map;
  const map = new Map();
  try {
    const snap = await admin.firestore()
        .collection('search_synonyms').doc('global').get();
    const pairs = (snap.exists && snap.data().pairs) || {};
    for (const [from, tos] of Object.entries(pairs)) {
      if (!Array.isArray(tos)) continue;
      map.set(from, new Set(tos.filter((t) => typeof t === 'string')));
    }
  } catch (e) {
    console.error('⚠️ [SIGNALS] loadLearnedSynonyms failed:', e.message);
    return _learnedCache.map;
  }
  _learnedCache = {at: Date.now(), map};
  return map;
}

async function expandSearchKeywords(query, keywords) {
  const base = new Set();
  for (const k of (keywords || [])) {
    for (const t of tokenize(k)) base.add(t);
  }
  for (const t of tokenize(query || '')) base.add(t);

  const learned = await loadLearnedSynonyms();
  const added = [];
  const seen = new Set(base);
  for (const term of base) {
    for (const src of [SEED_MAP.get(term), learned.get(term)]) {
      if (!src) continue;
      for (const syn of src) {
        if (seen.has(syn) || added.length >= SYNONYM_MAX_EXPANSIONS) continue;
        seen.add(syn);
        added.push(syn);
      }
    }
    if (added.length >= SYNONYM_MAX_EXPANSIONS) break;
  }
  return {baseTerms: [...base], expandedTerms: added};
}

function looseTermMatches(term, productLooseKeys) {
  const lk = looseKey(term);
  if (lk.length < LOOSE_MIN_LEN) return false;
  return productLooseKeys.has(lk);
}

function looseKeysFor(text) {
  const out = new Set();
  for (const t of String(text || '').toLowerCase().split(NON_WORD)) {
    if (t.length < 2) continue;
    const lk = looseKey(t);
    if (lk.length >= LOOSE_MIN_LEN) out.add(lk);
  }
  return out;
}

async function logSearchEvent(opts) {
  const uid = opts.uid;
  const query = String(opts.query || '').trim();
  if (!uid || query.length < 2) return null;
  const params = opts.searchParams || {};

  const priceTokens = new Set([params.minPrice, params.maxPrice]
      .filter((v) => v != null).map((v) => String(v)));
  const terms = tokenize(query).filter((t) => !priceTokens.has(t));
  if (terms.length === 0) return null;

  const id = admin.firestore().collection(RAW).doc().id;
  const ok = await writeEvent(id, {
    kind: KIND.SEARCH,
    userKey: userKey(uid),
    queryNorm: normalizeToken(query).slice(0, 120),
    terms: terms.slice(0, 12),
    resultCount: Number(opts.resultCount) || 0,
    zeroResult: (Number(opts.resultCount) || 0) === 0,
    candidatesBeforePriceFilter: Number(opts.candidatesBeforePriceFilter) || 0,
    priceFiltered: !!(params.minPrice || params.maxPrice),
    categoryHint: params.category || null,
    subcategoryHint: params.subcategory || null,
    brandHint: params.brand || null,
    modelHint: params.model || null,
    expandedWith: (opts.expandedTerms || []).slice(0, SYNONYM_MAX_EXPANSIONS),
  });
  return ok ? id : null;
}

async function logSearchClickEvent(opts) {
  const uid = opts.uid;
  const productId = String(opts.productId || '');
  if (!uid || !productId) return null;

  let queryNorm = null;
  let terms = [];
  if (opts.searchId) {
    try {
      const snap = await admin.firestore()
          .collection(RAW).doc(String(opts.searchId)).get();
      const ev = snap.exists ? snap.data() : null;
      if (ev && ev.kind === KIND.SEARCH && ev.userKey === userKey(uid)) {
        queryNorm = ev.queryNorm || null;
        terms = Array.isArray(ev.terms) ? ev.terms : [];
      }
    } catch (e) {
      console.error('⚠️ [SIGNALS] click parent lookup failed:', e.message);
    }
  }

  const id = admin.firestore().collection(RAW).doc().id;
  const ok = await writeEvent(id, {
    kind: KIND.CLICK,
    userKey: userKey(uid),
    productId,
    searchId: opts.searchId ? String(opts.searchId) : null,
    queryNorm,
    terms,
    rank: Number.isFinite(opts.rank) ? Number(opts.rank) : null,
  });
  return ok ? id : null;
}

async function beginListingSignal(uid, analysis) {
  if (!uid || !analysis) return null;
  const id = admin.firestore().collection(RAW).doc().id;
  const est = analysis.priceEstimate || {};
  const min = Number(est.min);
  const max = Number(est.max);
  const ok = await writeEvent(id, {
    kind: KIND.LISTING,
    complete: false,
    ttlDays: PENDING_LISTING_TTL_DAYS,
    sellerId: uid,
    source: 'analyzeProductImage',
    aiCategory: analysis.category || null,
    aiSubcategory: analysis.subcategory || null,
    aiBrand: analysis.brand || null,
    aiModel: analysis.model || null,
    aiCondition: analysis.condition || null,
    aiPriceMin: Number.isFinite(min) ? min : null,
    aiPriceMax: Number.isFinite(max) ? max : null,
    aiPriceMid: (Number.isFinite(min) && Number.isFinite(max)) ?
        Math.round((min + max) / 2) : null,
  });
  return ok ? id : null;
}

async function completeListingSignal(uid, analysisId, productId) {
  const db = admin.firestore();
  const ref = db.collection(RAW).doc(String(analysisId));
  const [evSnap, prodSnap] = await Promise.all([
    ref.get(),
    db.collection('products').doc(String(productId)).get(),
  ]);
  if (!evSnap.exists || !prodSnap.exists) return false;
  const ev = evSnap.data() || {};
  const p = prodSnap.data() || {};
  if (ev.kind !== KIND.LISTING || ev.sellerId !== uid) return false;
  if (p.sellerId !== uid) return false;
  if (ev.complete === true) return true;

  const finalCategory = p.categoryId || p.category || null;
  const finalSub = p.subCategoryId || p.subcategory || null;
  const completedDay = localDateKey(new Date(), 0);
  await ref.update({
    complete: true,
    completedDay,
    kindDay: `${KIND.LISTING}|${completedDay}`,
    productId: String(productId),
    kindProduct: `${KIND.LISTING}|${productId}`,
    isSeed: isSeedProduct(p),
    finalCategory,
    finalSubcategory: finalSub,
    finalBrand: p.brand || null,
    finalCondition: p.condition || null,
    listedPrice: Number(p.price) || null,
    categoryChanged: !!(ev.aiCategory && finalCategory &&
        normalizeToken(ev.aiCategory) !== normalizeToken(finalCategory)),
    subcategoryChanged: !!(ev.aiSubcategory && finalSub &&
        normalizeToken(ev.aiSubcategory) !== normalizeToken(finalSub)),
    completedAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: tsFromNow(LISTING_RETENTION_DAYS),
  });
  return true;
}

async function recordSaleEvents(orderId, order) {
  const db = admin.firestore();

  const paid = !!(order.stripePaymentIntentId || order.paidAt);

  const rawItems = Array.isArray(order.items) && order.items.length > 0 ?
      order.items :
      [{productId: order.productId,
        price: order.itemPrice != null ? order.itemPrice : order.productPrice}];

  const items = rawItems
      .filter((i) => i && i.productId)
      .slice(0, 20);
  if (items.length === 0) return 0;

  const prodSnaps = await db.getAll(
      ...items.map((i) => db.collection('products').doc(String(i.productId))));

  let written = 0;
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const snap = prodSnaps[i];
    if (!snap || !snap.exists) continue;
    const p = snap.data() || {};
    if (isSeedProduct(p)) continue;

    const keyParts = priceKeyPartsFor(p);
    const finalPrice = Number(item.price) || 0;
    if (finalPrice <= 0) continue;

    const listedAt = p.createdAt && p.createdAt.toMillis ?
        p.createdAt.toMillis() : null;
    const soldAt = order.createdAt && order.createdAt.toMillis ?
        order.createdAt.toMillis() : Date.now();
    const daysToSell = listedAt ?
        Math.max(0, Math.round((soldAt - listedAt) / 86400000)) : null;

    let aiPriceMid = null;
    let listedPrice = null;
    try {
      const listingSnap = await db.collection(RAW)
          .where('kindProduct', '==', `${KIND.LISTING}|${item.productId}`)
          .limit(1).get();
      if (!listingSnap.empty) {
        const l = listingSnap.docs[0].data() || {};
        aiPriceMid = l.aiPriceMid != null ? l.aiPriceMid : null;
        listedPrice = l.listedPrice != null ? l.listedPrice : null;
      }
    } catch (e) {
      console.error('⚠️ [SIGNALS] listing lookup failed:', e.message);
    }

    const ok = await writeEvent(`sale_${orderId}_${item.productId}`, {
      kind: KIND.SALE,
      orderId: String(orderId),
      productId: String(item.productId),
      sellerId: p.sellerId || order.sellerId || null,
      askingPrice: Number(p.price) || null,
      listedPrice: listedPrice,
      finalPrice,
      aiPriceMid,
      paid,
      paymentMethod: order.paymentMethod || null,
      category: keyParts ? keyParts.category : (p.categoryId || p.category || null),
      subcategory: keyParts ? keyParts.subcategory : null,
      brand: keyParts ? keyParts.brand : (p.brand || null),
      model: keyParts ? keyParts.model : null,
      condition: p.condition || null,
      daysToSell,
      retailKey: keyParts ? retailEstimateKey(keyParts) : null,
    });
    if (ok) written++;
  }
  return written;
}

exports.recordSaleSignal = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.status === 'completed' || after.status !== 'completed') {
        return null;
      }
      try {
        const n = await recordSaleEvents(context.params.orderId, after);
        if (n > 0) console.log(`💰 [SIGNALS] recorded ${n} sale event(s)`);
      } catch (e) {
        console.error('❌ [SIGNALS] recordSaleSignal failed:', e.message);
      }
      return null;
    });

exports.logSearchClick = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  const uid = context.auth.uid;
  const allowed = await checkRateLimit(uid, 'signal_click', 60, 60000);
  if (!allowed) return {ok: false, reason: 'rate_limited'};

  const productId = data && data.productId;
  if (!productId || typeof productId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'productId required');
  }
  const id = await logSearchClickEvent({
    uid,
    productId,
    searchId: data.searchId,
    rank: data.rank,
  });
  return {ok: !!id};
});

exports.logListingOutcome = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Login required');
  }
  const uid = context.auth.uid;
  const allowed = await checkRateLimit(uid, 'signal_listing', 30, 60000);
  if (!allowed) return {ok: false, reason: 'rate_limited'};

  const {analysisId, productId} = data || {};
  if (!analysisId || !productId ||
      typeof analysisId !== 'string' || typeof productId !== 'string') {
    throw new functions.https.HttpsError(
        'invalid-argument', 'analysisId and productId required');
  }
  try {
    const ok = await completeListingSignal(uid, analysisId, productId);
    return {ok};
  } catch (e) {
    console.error('⚠️ [SIGNALS] logListingOutcome failed:', e.message);
    return {ok: false};
  }
});

async function readDayEvents(kind, dateKey, cap) {
  const db = admin.firestore();
  const out = [];
  let last = null;
  while (out.length < cap) {
    let q = db.collection(RAW)
        .where('kindDay', '==', `${kind}|${dateKey}`)
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(300);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    if (snap.empty) break;
    snap.docs.forEach((d) => out.push({id: d.id, ...d.data()}));
    last = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 300) break;
  }
  return out;
}

function median(nums) {
  if (nums.length === 0) return null;
  const s = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : Math.round((s[mid - 1] + s[mid]) / 2);
}

function percentile(nums, p) {
  if (nums.length === 0) return null;
  const s = [...nums].sort((a, b) => a - b);
  const idx = Math.min(s.length - 1, Math.max(0, Math.round((s.length - 1) * p)));
  return s[idx];
}

async function rollupSales(dateKey) {
  const db = admin.firestore();
  const events = await readDayEvents(KIND.SALE, dateKey, 2000);
  const byKey = new Map();
  for (const ev of events) {
    if (!ev.retailKey) continue;
    if (!byKey.has(ev.retailKey)) byKey.set(ev.retailKey, []);
    byKey.get(ev.retailKey).push(ev);
  }
  if (byKey.size === 0) return {keys: 0, published: 0};

  let published = 0;
  for (const [key, evs] of byKey) {
    const statsRef = db.collection('price_stats').doc(key);
    const snap = await statsRef.get();
    const prev = snap.exists ? (snap.data() || {}) : {};
    const samples = Array.isArray(prev.samples) ? prev.samples : [];
    const seen = new Set(samples.map((s) => s.e));

    for (const ev of evs) {
      if (seen.has(ev.id)) continue;
      samples.push({
        e: ev.id,
        p: Number(ev.finalPrice) || 0,
        list: ev.listedPrice != null ? Number(ev.listedPrice) : null,
        ai: ev.aiPriceMid != null ? Number(ev.aiPriceMid) : null,
        d: ev.day || dateKey,
        cond: ev.condition || null,
        paid: !!ev.paid,
        dts: ev.daysToSell != null ? Number(ev.daysToSell) : null,
      });
    }

    const fresh = samples
        .filter((s) => daysBetweenKeys(dateKey, s.d) <= SALE_WINDOW_DAYS)
        .slice(-PRICE_SAMPLES_CAP);

    const first = evs[0];
    const prices = fresh.map((s) => s.p).filter((n) => n > 0);
    const n = prices.length;

    await statsRef.set({
      key,
      category: first.category || null,
      subcategory: first.subcategory || null,
      brand: first.brand || null,
      model: first.model || null,
      samples: fresh,
      sampleSize: n,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    const estRef = db.collection('retail_estimates').doc(key);
    const estSnap = await estRef.get();
    const est = estSnap.exists ? (estSnap.data() || {}) : {};

    if (n < MIN_COMPARABLE_SALES) {
      if (est.source === 'sales_v1' && est.supersededAi) {
        await estRef.set({
          ...est.supersededAi,
          supersededAi: admin.firestore.FieldValue.delete(),
          revertedAt: admin.firestore.FieldValue.serverTimestamp(),
          revertReason: 'sample_window_decayed',
        }, {merge: true});
      }
      continue;
    }

    const aiPairs = fresh.filter((s) => s.ai > 0 && s.p > 0);
    const aiBiasPct = aiPairs.length >= 3 ? Math.round(
        (aiPairs.reduce((acc, s) => acc + (s.p - s.ai) / s.ai, 0) /
         aiPairs.length) * 100) : null;
    const dts = fresh.map((s) => s.dts).filter((v) => Number.isFinite(v));

    const payload = {
      keyHash: key,
      source: 'sales_v1',
      category: first.category || null,
      subcategory: first.subcategory || null,
      brand: first.brand || null,
      model: first.model || null,
      resaleEstimate: median(prices),
      resaleP25: percentile(prices, 0.25),
      resaleP75: percentile(prices, 0.75),
      [RETAIL_VALUE_FIELD]: median(prices),
      salesValueField: RETAIL_VALUE_FIELD,
      sampleSize: n,
      paidSampleSize: fresh.filter((s) => s.paid).length,
      windowDays: SALE_WINDOW_DAYS,
      aiBiasPct,
      medianDaysToSell: dts.length >= 3 ? median(dts) : null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (est.source && est.source !== 'sales_v1' && !est.supersededAi) {
      payload.supersededAi = est;
    }
    await estRef.set(payload, {merge: true});
    published++;
  }
  return {keys: byKey.size, published};
}

function extractSynonymPair(failedTerms, successTerms) {
  const a = new Set(failedTerms || []);
  const b = new Set(successTerms || []);
  const onlyA = [...a].filter((t) => !b.has(t));
  const onlyB = [...b].filter((t) => !a.has(t));
  if (onlyA.length !== 1 || onlyB.length !== 1) return null;
  const from = onlyA[0];
  const to = onlyB[0];
  if (from === to) return null;
  if (/\d/.test(from) || /\d/.test(to)) return null;
  if (from.length < 2 || to.length < 2) return null;
  const ktiv = looseKey(from).length >= LOOSE_MIN_LEN &&
      looseKey(from) === looseKey(to);
  return {from, to, ktiv};
}

async function rollupSynonyms(dateKey) {
  const db = admin.firestore();
  const [searches, clicks] = await Promise.all([
    readDayEvents(KIND.SEARCH, dateKey, 5000),
    readDayEvents(KIND.CLICK, dateKey, 5000),
  ]);
  if (clicks.length === 0) return {candidates: 0, published: 0};

  const failedByUser = new Map();
  for (const s of searches) {
    if (!s.zeroResult || s.priceFiltered) continue;
    if (!failedByUser.has(s.userKey)) failedByUser.set(s.userKey, []);
    failedByUser.get(s.userKey).push(s);
  }
  for (const arr of failedByUser.values()) arr.sort((x, y) => x.atMs - y.atMs);

  const candidates = new Map();
  for (const c of clicks) {
    if (!c.queryNorm || !Array.isArray(c.terms) || c.terms.length === 0) continue;
    const prior = failedByUser.get(c.userKey) || [];
    let best = null;
    for (const f of prior) {
      if (f.atMs >= c.atMs) break;
      if (c.atMs - f.atMs > SYNONYM_CHAIN_WINDOW_MS) continue;
      if (f.queryNorm === c.queryNorm) continue;
      best = f;
    }
    if (!best) continue;
    const pair = extractSynonymPair(best.terms, c.terms);
    if (!pair) continue;
    const pk = `${pair.from}__${pair.to}`;
    if (!candidates.has(pk)) {
      candidates.set(pk, {...pair, users: new Set(), chains: 0});
    }
    candidates.get(pk).users.add(c.userKey);
    candidates.get(pk).chains++;
  }
  if (candidates.size === 0) return {candidates: 0, published: 0};

  for (const [pk, cand] of candidates) {
    const ref = db.collection('synonym_candidates').doc(
        crypto.createHash('sha1').update(pk).digest('hex').slice(0, 32));
    await ref.set({
      from: cand.from,
      to: cand.to,
      ktiv: cand.ktiv,
      users: admin.firestore.FieldValue.arrayUnion(...cand.users),
      chains: admin.firestore.FieldValue.increment(cand.chains),
      lastSeenDay: dateKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  const all = await db.collection('synonym_candidates').limit(2000).get();
  const pairs = {};
  let publishedCount = 0;
  for (const d of all.docs) {
    const c = d.data() || {};
    const users = Array.isArray(c.users) ? c.users.length : 0;
    const need = c.ktiv ? SYNONYM_MIN_USERS_KTIV : SYNONYM_MIN_USERS;
    if (users < need) continue;
    if (publishedCount >= SYNONYM_MAX_PUBLISHED) break;
    if (!pairs[c.from]) pairs[c.from] = [];
    if (!pairs[c.from].includes(c.to)) {
      pairs[c.from].push(c.to);
      publishedCount++;
    }
  }
  await db.collection('search_synonyms').doc('global').set({
    pairs,
    pairCount: publishedCount,
    minDistinctUsers: SYNONYM_MIN_USERS,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {candidates: candidates.size, published: publishedCount};
}

async function rollupCategoryCorrections(dateKey) {
  const db = admin.firestore();
  const events = await readDayEvents(KIND.LISTING, dateKey, 2000);
  const byAi = new Map();
  for (const ev of events) {
    if (ev.complete !== true) continue;
    if (ev.isSeed) continue;
    if (!ev.aiCategory) continue;
    const k = ev.aiCategory;
    if (!byAi.has(k)) {
      byAi.set(k, {kept: 0, changed: 0, to: {}, sub: {}});
    }
    const agg = byAi.get(k);
    if (ev.categoryChanged && ev.finalCategory) {
      agg.changed++;
      agg.to[ev.finalCategory] = (agg.to[ev.finalCategory] || 0) + 1;
    } else {
      agg.kept++;
    }
    if (ev.aiSubcategory && ev.finalSubcategory && ev.subcategoryChanged) {
      if (!agg.sub[ev.aiSubcategory]) agg.sub[ev.aiSubcategory] = {};
      const s = agg.sub[ev.aiSubcategory];
      s[ev.finalSubcategory] = (s[ev.finalSubcategory] || 0) + 1;
    }
  }
  if (byAi.size === 0) return {categories: 0};

  for (const [aiCategory, agg] of byAi) {
    const ref = db.collection('category_corrections').doc(aiCategory);
    const to = {};
    for (const [k, n] of Object.entries(agg.to)) {
      to[k] = admin.firestore.FieldValue.increment(n);
    }
    const sub = {};
    for (const [aiSub, m] of Object.entries(agg.sub)) {
      sub[aiSub] = {};
      for (const [finalSub, n] of Object.entries(m)) {
        sub[aiSub][finalSub] = admin.firestore.FieldValue.increment(n);
      }
    }
    await ref.set({
      aiCategory,
      total: admin.firestore.FieldValue.increment(agg.kept + agg.changed),
      kept: admin.firestore.FieldValue.increment(agg.kept),
      changed: admin.firestore.FieldValue.increment(agg.changed),
      to,
      sub,
      lastDay: dateKey,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  return {categories: byAi.size};
}

function demandClusterId(terms) {
  const canonical = [...new Set(
      terms.map((t) => SEED_CANONICAL.get(t) || t),
  )].sort();
  return {
    canonical,
    id: crypto.createHash('sha1').update(canonical.join('|'))
        .digest('hex').slice(0, 32),
  };
}

async function rollupDemand(dateKey) {
  const db = admin.firestore();
  const searches = await readDayEvents(KIND.SEARCH, dateKey, 5000);
  const clusters = new Map();
  for (const s of searches) {
    if (!s.zeroResult) continue;
    if (!Array.isArray(s.terms) || s.terms.length === 0) continue;
    const {canonical, id} = demandClusterId(s.terms);
    if (!clusters.has(id)) {
      clusters.set(id, {
        terms: canonical, users: new Set(), priceUsers: new Set(),
        searches: 0, categoryHint: s.categoryHint || null,
      });
    }
    const c = clusters.get(id);
    c.searches++;
    if (s.priceFiltered && s.candidatesBeforePriceFilter > 0) {
      c.priceUsers.add(s.userKey);
    } else {
      c.users.add(s.userKey);
    }
    if (!c.categoryHint && s.categoryHint) c.categoryHint = s.categoryHint;
  }
  if (clusters.size === 0) return {clusters: 0, published: 0};

  let published = 0;
  for (const [id, c] of clusters) {
    const intRef = db.collection('demand_signals_internal').doc(id);
    const snap = await intRef.get();
    const prev = snap.exists ? (snap.data() || {}) : {};
    const days = (prev.days && typeof prev.days === 'object') ? prev.days : {};

    days[dateKey] = [...new Set([
      ...(Array.isArray(days[dateKey]) ? days[dateKey] : []),
      ...c.users,
    ])].slice(0, DEMAND_USERS_PER_DAY_CAP);
    const priceDays = (prev.priceDays && typeof prev.priceDays === 'object') ?
        prev.priceDays : {};
    priceDays[dateKey] = [...new Set([
      ...(Array.isArray(priceDays[dateKey]) ? priceDays[dateKey] : []),
      ...c.priceUsers,
    ])].slice(0, DEMAND_USERS_PER_DAY_CAP);

    const keep = (map) => {
      const out = {};
      for (const [d, arr] of Object.entries(map)) {
        if (daysBetweenKeys(dateKey, d) <= DEMAND_WINDOW_DAYS) out[d] = arr;
      }
      return out;
    };
    const keptDays = keep(days);
    const keptPriceDays = keep(priceDays);

    const union = (map, withinDays) => {
      const set = new Set();
      for (const [d, arr] of Object.entries(map)) {
        if (daysBetweenKeys(dateKey, d) > withinDays) continue;
        for (const u of arr) set.add(u);
      }
      return set;
    };
    const users30 = union(keptDays, DEMAND_WINDOW_DAYS);
    const users7 = union(keptDays, DEMAND_RECENT_DAYS);
    const priceUsers30 = union(keptPriceDays, DEMAND_WINDOW_DAYS);

    const searchDays = (prev.searchDays && typeof prev.searchDays === 'object') ?
        prev.searchDays : {};
    searchDays[dateKey] = (Number(searchDays[dateKey]) || 0) + c.searches;
    const keptSearchDays = {};
    let searches30 = 0;
    for (const [d, n] of Object.entries(searchDays)) {
      if (daysBetweenKeys(dateKey, d) > DEMAND_WINDOW_DAYS) continue;
      keptSearchDays[d] = n;
      searches30 += Number(n) || 0;
    }

    await intRef.set({
      terms: c.terms,
      days: keptDays,
      priceDays: keptPriceDays,
      searchDays: keptSearchDays,
      searches30,
      categoryHint: c.categoryHint || prev.categoryHint || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const pubRef = db.collection('demand_signals').doc(id);
    if (users30.size < DEMAND_MIN_USERS) {
      if ((await pubRef.get()).exists) await pubRef.delete();
      continue;
    }
    await pubRef.set({
      terms: c.terms,
      phrase: c.terms.join(' '),
      distinctUsers7d: users7.size,
      distinctUsers30d: users30.size,
      priceConstrainedUsers30d: priceUsers30.size,
      searches30d: searches30,
      categoryHint: c.categoryHint || null,
      score: users7.size * 2 + (users30.size - users7.size),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    published++;
  }
  return {clusters: clusters.size, published};
}

async function pruneRawEvents() {
  const db = admin.firestore();
  const snap = await db.collection(RAW)
      .where('expiresAt', '<=', admin.firestore.Timestamp.now())
      .limit(PRUNE_PER_RUN).get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return snap.size;
}

exports.rollupSignals = functions.pubsub
    .schedule('20 0 * * *')
    .timeZone('Asia/Jerusalem')
    .onRun(async () => {
      const db = admin.firestore();
      const dateKey = localDateKey(new Date(), 1);
      const stateRef = db.collection('signal_rollup_state').doc(dateKey);
      const state = (await stateRef.get()).data() || {};
      const done = state.stages || {};

      const stages = [
        ['sales', rollupSales],
        ['synonyms', rollupSynonyms],
        ['categories', rollupCategoryCorrections],
        ['demand', rollupDemand],
      ];

      for (const [name, fn] of stages) {
        if (done[name] === true) {
          console.log(`⏭️ [SIGNALS] ${name} already rolled up for ${dateKey}`);
          continue;
        }
        try {
          const res = await fn(dateKey);
          await stateRef.set({
            stages: {[name]: true},
            results: {[name]: res},
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          console.log(`✅ [SIGNALS] ${name} ${dateKey}:`, JSON.stringify(res));
        } catch (e) {
          console.error(`❌ [SIGNALS] ${name} rollup failed:`, e.message);
        }
      }

      try {
        const pruned = await pruneRawEvents();
        if (pruned > 0) console.log(`🧹 [SIGNALS] pruned ${pruned} raw event(s)`);
      } catch (e) {
        console.error('❌ [SIGNALS] prune failed:', e.message);
      }
      return null;
    });

exports.logSearchEvent = logSearchEvent;
exports.logSearchClickEvent = logSearchClickEvent;
exports.beginListingSignal = beginListingSignal;
exports.completeListingSignal = completeListingSignal;
exports.recordSaleEvents = recordSaleEvents;
exports.expandSearchKeywords = expandSearchKeywords;
exports.looseTermMatches = looseTermMatches;
exports.looseKeysFor = looseKeysFor;
exports.retailEstimateKey = retailEstimateKey;
exports.normalizeToken = normalizeToken;
exports.productModelRaw = productModelRaw;
exports.looseKey = looseKey;
exports.tokenize = tokenize;
exports.userKey = userKey;
exports.KIND = KIND;

exports._signals = {
  extractSynonymPair,
  demandClusterId,
  priceKeyPartsFor,
  median,
  percentile,
  rollupSales,
  rollupSynonyms,
  rollupCategoryCorrections,
  rollupDemand,
  MIN_COMPARABLE_SALES,
  SYNONYM_MIN_USERS,
  DEMAND_MIN_USERS,
};
