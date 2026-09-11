const admin = require('firebase-admin');

const PRICE_BANDS = ['b0_50', 'b50_150', 'b150_400', 'b400_1000', 'b1000p'];

function bandOf(price) {
  const p = Number(price);
  if (!Number.isFinite(p) || p < 50) return 'b0_50';
  if (p < 150) return 'b50_150';
  if (p < 400) return 'b150_400';
  if (p < 1000) return 'b400_1000';
  return 'b1000p';
}

const MAX_KEY_LEN = 64;
const RESERVED_KEY_SHAPE = /^__.*__$/;
const RESERVED_KEY_NAMES = new Set(['__proto__', 'constructor', 'prototype']);

function weightKeyOf(raw) {
  const t = String(raw == null ? '' : raw).trim().replace(/\s+/g, ' ');
  if (!t || t.length > MAX_KEY_LEN) return '';
  if (RESERVED_KEY_NAMES.has(t) || RESERVED_KEY_SHAPE.test(t)) return '';
  return t;
}

function brandKeyOf(raw) {
  return weightKeyOf(raw).toLowerCase();
}

const BARGAIN_KEYS = ['bargain', 'standard'];

function ownWeight(map, key) {
  if (!map || !Object.prototype.hasOwnProperty.call(map, key)) return 0;
  return Number(map[key]) || 0;
}

const SIGNAL_WEIGHTS = {
  purchase: 10,
  offer_made: 7,
  add_to_cart: 6,
  like: 5,
  chat_started: 4,
  share: 4,
  view_detail: 1.5,
  unlike: -5,
  remove_from_cart: -3,
};

function computeEventWeight(type, opts = {}) {
  if (type === 'dwell') {
    const dwellMs = Number(opts.dwellMs) || 0;
    return Math.min(3, (dwellMs / 10000) * 3);
  }
  return SIGNAL_WEIGHTS[type] || 0;
}

const DECAY_HOURS_DIVISOR = 24 * 20;
const AGE_DECAY_DAYS_DIVISOR = 20;

function decayFactor(hoursSinceLastRun) {
  return Math.exp(-Math.max(0, hoursSinceLastRun) / DECAY_HOURS_DIVISOR);
}

function decayMap(map, factor, keyOf) {
  const summed = {};
  for (const [rawKey, v] of Object.entries(map || {})) {
    const k = keyOf ? keyOf(rawKey) : rawKey;
    if (!k) continue;
    summed[k] = ownWeight(summed, k) + (Number(v) || 0) * factor;
  }
  const out = {};
  for (const [k, v] of Object.entries(summed)) {
    if (Math.abs(v) > 1e-6) out[k] = v;
  }
  return out;
}

function decayWeights(weights, hoursSinceLastRun) {
  const factor = decayFactor(hoursSinceLastRun);
  const w = weights || {};
  return {
    categories: decayMap(w.categories, factor, weightKeyOf),
    brands: decayMap(w.brands, factor, brandKeyOf),
    sellers: decayMap(w.sellers, factor, weightKeyOf),
    priceBands: decayMap(w.priceBands, factor),
    conditions: decayMap(w.conditions, factor, weightKeyOf),
    subcategories: decayMap(w.subcategories, factor, weightKeyOf),
    cities: decayMap(w.cities, factor, weightKeyOf),
    bargains: decayMap(w.bargains, factor),
  };
}

function pruneWeightMap(map, {top = 30, minValue = 0.05} = {}) {
  const entries = Object.entries(map || {})
      .filter(([, v]) => v >= minValue)
      .sort((a, b) => b[1] - a[1])
      .slice(0, top);
  const out = {};
  for (const [k, v] of entries) out[k] = Math.round(v * 1000) / 1000;
  return out;
}

function mergeProfile(existing, events, {nowMs, hoursSinceLastRun}) {
  const weights = decayWeights(existing && existing.weights, hoursSinceLastRun);

  const newSearches = [];
  let cartWorking = Array.isArray(existing && existing.cartAdds) ?
    [...existing.cartAdds] : [];

  for (const e of events) {
    const eventMs = Number(e._eventMs) || nowMs;
    const ageDays = Math.max(0, (nowMs - eventMs) / (24 * 60 * 60 * 1000));
    const ageDecay = Math.exp(-ageDays / AGE_DECAY_DAYS_DIVISOR);
    const weight = computeEventWeight(e.type, {dwellMs: e.dwellMs});
    const contribution = weight * ageDecay;

    if (contribution !== 0) {
      const add = (map, key) => {
        if (!key) return;
        map[key] = ownWeight(map, key) + contribution;
      };

      add(weights.categories, weightKeyOf(e.category));
      add(weights.brands, brandKeyOf(e.brand));
      add(weights.sellers, weightKeyOf(e.sellerId));
      if (e.price != null) add(weights.priceBands, bandOf(e.price));

      add(weights.conditions, weightKeyOf(e.condition));
      add(weights.subcategories, weightKeyOf(e.subcategory));
      add(weights.cities, weightKeyOf(e.city));
      if (typeof e.isBargain === 'boolean') {
        add(weights.bargains, e.isBargain ? BARGAIN_KEYS[0] : BARGAIN_KEYS[1]);
      }
    }

    if (e.type === 'search' && e.query) {
      newSearches.push({q: e.query, atMs: eventMs});
    }

    if (e.type === 'add_to_cart' && e.productId) {
      cartWorking = cartWorking.filter((c) => c.productId !== e.productId);
      cartWorking.push({productId: e.productId, atMs: eventMs});
    }
    if ((e.type === 'purchase' || e.type === 'remove_from_cart') && e.productId) {
      cartWorking = cartWorking.filter((c) => c.productId !== e.productId);
    }
  }

  const recentSearches = [...newSearches].reverse()
      .concat(Array.isArray(existing && existing.recentSearches) ? existing.recentSearches : [])
      .slice(0, 10);

  const cartAdds = [...cartWorking]
      .sort((a, b) => b.atMs - a.atMs)
      .slice(0, 15);

  return {
    version: 2,
    updatedAt: admin.firestore.Timestamp.fromMillis(nowMs),
    weights: {
      categories: pruneWeightMap(weights.categories),
      brands: pruneWeightMap(weights.brands),
      sellers: pruneWeightMap(weights.sellers),
      conditions: pruneWeightMap(weights.conditions),
      subcategories: pruneWeightMap(weights.subcategories),
      cities: pruneWeightMap(weights.cities),
      priceBands: weights.priceBands,
      bargains: weights.bargains,
    },
    recentSearches,
    cartAdds,
    totalSignals: ((existing && existing.totalSignals) || 0) + events.length,
  };
}

const CURSOR_DOC_PATH = '_internal/tasteProfileCursor';
const FIRST_RUN_LOOKBACK_DAYS = 30;
const PAGE_SIZE = 2000;

function profileDocPath(uid) {
  return `users/${uid}/private/tasteProfile`;
}

async function runUpdateTasteProfiles(db) {
  const nowMs = Date.now();
  const cursorRef = db.doc(CURSOR_DOC_PATH);
  const cursorSnap = await cursorRef.get();
  const cursorData = cursorSnap.exists ? cursorSnap.data() : null;

  const hasCursor = !!(cursorData && cursorData.lastRunAt &&
    typeof cursorData.lastRunAt.toMillis === 'function');
  const lastRunAtMs = hasCursor ?
    cursorData.lastRunAt.toMillis() :
    nowMs - FIRST_RUN_LOOKBACK_DAYS * 24 * 60 * 60 * 1000;
  const hoursSinceLastRun = Math.max(0, (nowMs - lastRunAtMs) / (60 * 60 * 1000));
  const lastRunAtTs = admin.firestore.Timestamp.fromMillis(lastRunAtMs);

  const eventsByUser = new Map();
  let lastDoc = null;
  let scanned = 0;
  let latestEventMs = lastRunAtMs;

  for (;;) {
    let q = db.collection('user_interactions')
        .where('createdAt', '>', lastRunAtTs)
        .orderBy('createdAt', 'asc')
        .limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const e = doc.data() || {};
      if (!e.userId || !e.type) continue;
      const createdAt = e.createdAt;
      const eventMs = createdAt && typeof createdAt.toMillis === 'function' ?
        createdAt.toMillis() : nowMs;
      latestEventMs = Math.max(latestEventMs, eventMs);
      if (!eventsByUser.has(e.userId)) eventsByUser.set(e.userId, []);
      eventsByUser.get(e.userId).push({...e, _eventMs: eventMs});
    }

    scanned += snap.docs.length;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(`[tasteProfile] scanned ${scanned} interaction(s) across ${eventsByUser.size} user(s) since ${new Date(lastRunAtMs).toISOString()}`);

  let usersUpdated = 0;
  for (const [userId, events] of eventsByUser.entries()) {
    try {
      const profileRef = db.doc(profileDocPath(userId));
      const profileSnap = await profileRef.get();
      const existing = profileSnap.exists ? profileSnap.data() : null;
      const merged = mergeProfile(existing, events, {nowMs, hoursSinceLastRun});
      await profileRef.set(merged);
      usersUpdated++;
    } catch (e) {
      console.error(`[tasteProfile] failed updating profile for ${userId}:`, e);
    }
  }

  const nextCursorMs = scanned > 0 ? latestEventMs : nowMs;
  await cursorRef.set({lastRunAt: admin.firestore.Timestamp.fromMillis(nextCursorMs)}, {merge: true});

  console.log(`[tasteProfile] updated ${usersUpdated} profile(s); cursor advanced to ${new Date(nextCursorMs).toISOString()}`);
  return {scanned, usersUpdated};
}

function normalizedWeightMap(map, keyOf) {
  const out = {};
  for (const [rawKey, v] of Object.entries(map || {})) {
    const k = keyOf ? keyOf(rawKey) : rawKey;
    if (!k) continue;
    out[k] = ownWeight(out, k) + (Number(v) || 0);
  }
  let max = 0;
  for (const k of Object.keys(out)) max = Math.max(max, out[k]);
  return {max: max > 0 ? max : 1, map: out};
}

function computeAffinity(profile, product) {
  if (!profile || !profile.weights) return 0;
  const weights = profile.weights;
  const cat = normalizedWeightMap(weights.categories, weightKeyOf);
  const brand = normalizedWeightMap(weights.brands, brandKeyOf);
  const seller = normalizedWeightMap(weights.sellers, weightKeyOf);
  const price = normalizedWeightMap(weights.priceBands);

  const catW = product.category ?
    ownWeight(cat.map, weightKeyOf(product.category)) / cat.max : 0;
  const brandW = product.brand ?
    ownWeight(brand.map, brandKeyOf(product.brand)) / brand.max : 0;
  const sellerW = product.sellerId ?
    ownWeight(seller.map, weightKeyOf(product.sellerId)) / seller.max : 0;
  const priceW = product.price != null ?
    ownWeight(price.map, bandOf(product.price)) / price.max : 0;

  let searchBoost = 0;
  const searches = Array.isArray(profile.recentSearches) ? profile.recentSearches : [];
  const title = String(product.title || '').toLowerCase();
  searches.forEach((s, idx) => {
    const terms = String((s && s.q) || '').toLowerCase().split(/\s+/).filter((t) => t.length >= 3);
    const hit = terms.some((t) => title.includes(t));
    if (hit) searchBoost = Math.max(searchBoost, idx === 0 ? 3.0 : 2.0);
  });

  let cartBoost = 0;
  const cartAdds = Array.isArray(profile.cartAdds) ? profile.cartAdds : [];
  const nowMs = Date.now();
  const inCartOverTwoHours = cartAdds.some((c) =>
    c.productId === product.id && (nowMs - Number(c.atMs || 0)) > 2 * 60 * 60 * 1000);
  if (inCartOverTwoHours) cartBoost = 8.0;

  const affinity = 3 * catW + 2 * brandW + 1 * sellerW + 1 * priceW + searchBoost + cartBoost;
  return Math.max(0, Math.min(1, affinity / 18));
}

module.exports = {
  PRICE_BANDS,
  BARGAIN_KEYS,
  SIGNAL_WEIGHTS,
  CURSOR_DOC_PATH,
  MAX_KEY_LEN,
  bandOf,
  weightKeyOf,
  brandKeyOf,
  ownWeight,
  computeEventWeight,
  decayFactor,
  decayWeights,
  pruneWeightMap,
  mergeProfile,
  computeAffinity,
  profileDocPath,
  runUpdateTasteProfiles,
};
