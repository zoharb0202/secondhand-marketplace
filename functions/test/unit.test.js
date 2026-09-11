const test = require('node:test');
const assert = require('node:assert');

const expectedPrice = require('../src/expectedPrice');
const legalConsent = require('../src/legalConsent');

const tasteProfile = require('../src/tasteProfile');

const signals = require('../src/signals');
const {_searchScoring, _llm} = require('../src/aiSearch');
const israelRegions = require('../src/israelRegions');

test('clientIpFrom takes the FIRST x-forwarded-for entry', () => {
  const req = {
    headers: {'x-forwarded-for': '203.0.113.7, 130.211.0.1, 35.191.0.5'},
    ip: '169.254.1.1',
  };
  assert.strictEqual(legalConsent.clientIpFrom(req), '203.0.113.7');
});

test('clientIpFrom handles a single-entry header', () => {
  assert.strictEqual(
      legalConsent.clientIpFrom({headers: {'x-forwarded-for': '198.51.100.9'}}),
      '198.51.100.9');
});

test('clientIpFrom falls back to req.ip when the header is absent', () => {
  assert.strictEqual(
      legalConsent.clientIpFrom({headers: {}, ip: '198.51.100.4'}),
      '198.51.100.4');
});

test('clientIpFrom returns null rather than guessing', () => {
  assert.strictEqual(legalConsent.clientIpFrom(null), null);
  assert.strictEqual(legalConsent.clientIpFrom({headers: {}}), null);
});

test('clientIpFrom caps a hostile header length', () => {
  const long = 'a'.repeat(500);
  assert.ok(legalConsent.clientIpFrom({headers: {'x-forwarded-for': long}}).length <= 64);
});

const today = new Date().toISOString().slice(0, 10);
const samplesOf = (cond, base, n) =>
  Array.from({length: n}, (_, i) => ({e: `${cond}${i}`, p: base + i * 10, cond, d: today, dts: 5}));

function fakeStatsDb(samples) {
  return {
    collection: () => ({
      doc: () => ({
        get: async () => ({exists: true, data: () => ({samples, brand: 'Apple'})}),
      }),
    }),
  };
}

test('expectedPriceFor answers per condition, not blended', async () => {
  const db = fakeStatsDb([
    ...samplesOf('good', 800, 6),
    ...samplesOf('likeNew', 1100, 4),
    ...samplesOf('forParts', 150, 5),
  ]);
  const good = await expectedPrice.expectedPriceFor(db, 'k', 'good');
  const likeNew = await expectedPrice.expectedPriceFor(db, 'k', 'likeNew');
  const parts = await expectedPrice.expectedPriceFor(db, 'k', 'forParts');

  assert.strictEqual(good.basis, 'condition');
  assert.strictEqual(likeNew.basis, 'condition');
  assert.strictEqual(parts.basis, 'condition');
  assert.ok(likeNew.expected > good.expected);
  assert.ok(good.expected > parts.expected);
  const blended = await expectedPrice.expectedPriceFor(db, 'k', null);
  assert.notStrictEqual(blended.expected, likeNew.expected);
});

test('expectedPriceFor borrows from adjacent conditions, and says so', async () => {
  const db = fakeStatsDb([
    ...samplesOf('likeNew', 1100, 4),
    ...samplesOf('good', 800, 6),
  ]);
  const r = await expectedPrice.expectedPriceFor(db, 'k', 'new');
  assert.strictEqual(r.basis, 'adjacent_conditions');
  assert.ok(r.expected >= 1100);
});

test('expectedPriceFor never borrows across the whole ladder', async () => {
  const db = fakeStatsDb(samplesOf('forParts', 150, 5));
  const r = await expectedPrice.expectedPriceFor(db, 'k', 'new');
  assert.strictEqual(r.basis, 'all_conditions',
      'must fall back to the labelled blend, not silently borrow from forParts');
});

test('expectedPriceFor ignores a bucket below the sample floor', async () => {
  const db = fakeStatsDb([
    ...samplesOf('likeNew', 5000, 2),
    ...samplesOf('good', 800, 8),
  ]);
  const r = await expectedPrice.expectedPriceFor(db, 'k', 'likeNew');
  assert.notStrictEqual(r.basis, 'condition');
  assert.ok(!('likeNew' in r.byCondition));
});

test('expectedPriceFor drops samples outside the window', async () => {
  const old = '2020-01-01';
  const db = fakeStatsDb([
    {e: 'a', p: 9999, cond: 'good', d: old},
    ...samplesOf('good', 800, 5),
  ]);
  const r = await expectedPrice.expectedPriceFor(db, 'k', 'good');
  assert.strictEqual(r.sampleSize, 5, 'the 2020 sale must not count');
});

test('expectedPriceFor returns null when nothing is known', async () => {
  const missing = {collection: () => ({doc: () => ({get: async () => ({exists: false})})})};
  assert.strictEqual(await expectedPrice.expectedPriceFor(missing, 'k', 'good'), null);
});

test('median resists a single mispriced outlier', () => {
  assert.strictEqual(expectedPrice.median([1, 800, 810, 820, 830]), 810);
});

const trendingScore = require('../src/trendingScore');

const dayKey = (_at, daysAgo) => `d${daysAgo}`;
const days = (map) => ({days: map});

function scoreOf(dailyStats, extra) {
  return trendingScore.trendScoreFor({
    product: {createdAt: null},
    dailyStats,
    nowMs: Date.UTC(2026, 7, 18),
    dateKeyFn: dayKey,
    ...(extra || {}),
  });
}

test('ten carts and ten chats outrank a hundred scroll-by views', () => {
  const browsed = scoreOf(days({d0: {views: 100}}));
  const wanted = scoreOf(days({d0: {carts: 10, chats: 10}}));

  assert.ok(wanted.score > browsed.score,
      `intent ${wanted.score} must beat idle views ${browsed.score}`);
  assert.ok(wanted.score > browsed.score * 1.5);
});

test('a single chat outweighs a pile of views, an offer outweighs more', () => {
  const views = scoreOf(days({d0: {views: 40}}));
  const chat = scoreOf(days({d0: {chats: 1}}));
  const offer = scoreOf(days({d0: {offers: 1}}));
  assert.ok(chat.score > views.score);
  assert.ok(offer.score > chat.score);
});

test('the weight ladder is ordered by how much intent each act proves', () => {
  const w = trendingScore.SIGNAL_WEIGHTS;
  assert.ok(w.purchase > w.offer);
  assert.ok(w.offer > w.chat);
  assert.ok(w.chat > w.addToCart);
  assert.ok(w.addToCart > w.share);
  assert.ok(w.share > w.like);
  assert.ok(w.like > w.dwell);
  assert.ok(w.dwell > w.view);
});

test('attention saturates so raw volume cannot buy the top slot', () => {
  const some = scoreOf(days({d0: {views: 100}}));
  const flood = scoreOf(days({d0: {views: 10000}}));
  assert.ok(flood.score > some.score, 'more views must still count for something');
  assert.ok(flood.score < some.score * 3,
      `runaway scale: ${some.score} -> ${flood.score}`);
});

test('dwell is bounded — one long read cannot pose as four readers', () => {
  const oneLongRead = trendingScore.dwellPointsOf({dwells: 1, dwellMs: 120000});
  const fourReads = trendingScore.dwellPointsOf({dwells: 4, dwellMs: 120000});
  assert.strictEqual(oneLongRead, trendingScore.SIGNAL_WEIGHTS.dwell);
  assert.ok(fourReads > oneLongRead);
  assert.ok(trendingScore.dwellPointsOf({dwells: 4, dwellMs: 8000}) < oneLongRead);
  assert.strictEqual(trendingScore.dwellPointsOf({dwells: 0, dwellMs: 999999}), 0);
});

test('seller strength nudges and can never dominate', () => {
  const perfect = {
    sellerRating: 5, totalReviews: 400, totalSales: 900, isSellerVerified: true,
  };
  const unknown = {};

  assert.ok(trendingScore.sellerBoostOf(perfect, 999) <=
    1 + trendingScore.SELLER_MAX_BOOST + 1e-9);
  assert.strictEqual(trendingScore.sellerBoostOf(unknown, 0), 1);

  const veteran = scoreOf(days({d0: {chats: 1}}), {seller: perfect, recentSellerSales: 50});
  const newcomer = scoreOf(days({d0: {chats: 2}}), {seller: unknown});
  assert.ok(newcomer.score > veteran.score,
      `a new seller's more-wanted item must win: ${newcomer.score} vs ${veteran.score}`);

  const reputationOnly = scoreOf(days({}), {seller: perfect, recentSellerSales: 50});
  assert.strictEqual(reputationOnly.score, 0);
  assert.ok(scoreOf(days({d0: {likes: 1}}), {seller: unknown}).score > reputationOnly.score);
});

test('a 5.0 from one review is not a record', () => {
  const thin = trendingScore.sellerStrengthOf(
      {sellerRating: 5, totalReviews: 1}, 0);
  const real = trendingScore.sellerStrengthOf(
      {sellerRating: 5, totalReviews: trendingScore.SELLER_MIN_REVIEWS}, 0);
  assert.strictEqual(thin, 0);
  assert.ok(real > 0);
  assert.strictEqual(trendingScore.sellerStrengthOf({sellerRating: 2, totalReviews: 50}, 0), 0);
  assert.ok(trendingScore.sellerStrengthOf({}, 0) >= 0);
});

test('purchases lift the seller, which is what a purchase leaves behind', () => {
  const quiet = trendingScore.sellerStrengthOf({sellerRating: 4.5, totalReviews: 10}, 0);
  const moving = trendingScore.sellerStrengthOf({sellerRating: 4.5, totalReviews: 10}, 8);
  assert.ok(moving > quiet);
  assert.ok(trendingScore.sellerBoostOf({sellerRating: 4.5, totalReviews: 10}, 100) <=
    1 + trendingScore.SELLER_MAX_BOOST + 1e-9);
});

test('a brand-new product with no signal scores 0 — not NaN, not negative', () => {
  const cold = trendingScore.trendScoreFor({product: {}, dailyStats: null});
  assert.strictEqual(cold.score, 0);
  assert.ok(Number.isFinite(cold.score));

  for (const args of [
    {},
    {product: null, dailyStats: undefined, seller: null},
    {product: {viewCount: null, likeCount: 'x', createdAt: 'nonsense'}, dailyStats: {days: null}},
    {product: {viewCount: -50, likeCount: -3}, dailyStats: {days: {d0: {views: -9, carts: -9}}},
      dateKeyFn: dayKey, seller: {sellerRating: NaN, totalSales: undefined}},
  ]) {
    const r = trendingScore.trendScoreFor(args);
    assert.ok(Number.isFinite(r.score), `score must be finite for ${JSON.stringify(args)}`);
    assert.ok(r.score >= 0, `score must never be negative (got ${r.score})`);
  }
});

test('age decay survives the rewrite, floor included', () => {
  assert.strictEqual(trendingScore.ageFactorOf(0), 1);
  assert.ok(trendingScore.ageFactorOf(365) >= trendingScore.AGE_FLOOR);
  assert.ok(trendingScore.ageFactorOf(365) < trendingScore.AGE_FLOOR + 0.01);

  const nowMs = Date.UTC(2026, 7, 18);
  const withAge = (ageDays) => trendingScore.trendScoreFor({
    product: {createdAt: new Date(nowMs - ageDays * 86400000)},
    dailyStats: days({d0: {chats: 2}}),
    nowMs, dateKeyFn: dayKey,
  }).score;
  assert.ok(withAge(0) > withAge(30), 'the same traction on an old listing must decay');
  assert.ok(withAge(200) > 0, 'decay dampens, it never erases');
});

test('windowCountsFrom weights the last three days and clamps a negative day', () => {
  const counts = trendingScore.windowCountsFrom(
      {d0: {carts: 1}, d4: {carts: 1}, d9: {carts: 100}},
      {nowMs: 1, dateKeyFn: dayKey});
  assert.strictEqual(counts.carts, trendingScore.RECENT_DAY_WEIGHT * 1 + 1);

  const withRetraction = trendingScore.windowCountsFrom(
      {d0: {carts: -5}, d5: {carts: 2}}, {nowMs: 1, dateKeyFn: dayKey});
  assert.strictEqual(withRetraction.carts, 2);
});

test('the rollup imports only what the daily map has no column for', () => {
  const positive = trendingScore.POSITIVE_INTERACTIONS;
  assert.ok(!('view_detail' in positive), 'view_detail is already in `views`');
  assert.ok(!('like' in positive), 'like is already in `likes`');
  for (const t of ['add_to_cart', 'chat_started', 'offer_made', 'share', 'purchase']) {
    assert.ok(positive[t], `${t} must be rolled up`);
  }
  assert.strictEqual(trendingScore.NEGATIVE_INTERACTIONS.remove_from_cart, 'carts');
});

const rollupNow = Date.UTC(2026, 7, 18, 12);
const rollupDay = trendingScore.localDateKey(new Date(rollupNow), 0);

function interaction(type, userId, extra) {
  return {
    type, userId, productId: 'p1',
    createdAt: {toMillis: () => rollupNow},
    ...(extra || {}),
  };
}

function foldAll(events) {
  const acc = trendingScore.newSignalAccumulator();
  events.forEach((e, i) => trendingScore.foldInteractionEvent(acc, `doc${i}`, e, rollupNow));
  return {acc, day: (acc.products.get('p1') || {})[rollupDay] || {}};
}

test('one account cannot vote twice — intent is deduped per person per day', () => {
  const events = [];
  for (let i = 0; i < 10; i++) events.push(interaction('chat_started', 'u1'));
  events.push(interaction('chat_started', 'u2'));
  assert.strictEqual(foldAll(events).day.chats, 2);

  const flood = [];
  for (let i = 0; i < 1000; i++) flood.push(interaction('offer_made', 'attacker'));
  assert.strictEqual(foldAll(flood).day.offers, 1);
});

test('dedup is per (product, actor, type, day) and nothing coarser', () => {
  const mixed = foldAll([
    interaction('chat_started', 'u1'),
    interaction('add_to_cart', 'u1'),
    interaction('share', 'u1'),
  ]).day;
  assert.strictEqual(mixed.chats, 1);
  assert.strictEqual(mixed.carts, 1);
  assert.strictEqual(mixed.shares, 1);

  const acc = trendingScore.newSignalAccumulator();
  trendingScore.foldInteractionEvent(acc, 'a', interaction('chat_started', 'u1'), rollupNow);
  trendingScore.foldInteractionEvent(
      acc, 'b', {...interaction('chat_started', 'u1'), productId: 'p2'}, rollupNow);
  assert.strictEqual(acc.products.get('p1')[rollupDay].chats, 1);
  assert.strictEqual(acc.products.get('p2')[rollupDay].chats, 1);

  const anon = foldAll([
    interaction('chat_started', undefined),
    interaction('chat_started', null),
  ]).day;
  assert.strictEqual(anon.chats, 2);
});

test('an add/remove pair from one person nets to nothing', () => {
  const day = foldAll([
    interaction('add_to_cart', 'u1'),
    interaction('add_to_cart', 'u1'),
    interaction('remove_from_cart', 'u1'),
  ]).day;
  assert.strictEqual(day.carts, 0);

  const acc = trendingScore.newSignalAccumulator();
  for (let i = 0; i < 5; i++) {
    trendingScore.foldInteractionEvent(
        acc, `p${i}`, interaction('purchase', 'u1', {sellerId: 's1'}), rollupNow);
  }
  assert.strictEqual(acc.products.get('p1')[rollupDay].purchases, 1);
  assert.strictEqual(acc.sellers.get('s1')[rollupDay].purchases, 1);
});

test('lifetime sales are read from the field the server actually increments', () => {
  const withStats = trendingScore.sellerStrengthOf(
      {sellerRating: 0, totalReviews: 0, stats: {totalSales: 40}}, 0);
  assert.ok(withStats > 0, 'a seller with 40 completed sales must score above zero');
  assert.strictEqual(
      withStats,
      trendingScore.sellerStrengthOf({sellerRating: 0, totalSales: 40}, 0),
      'both spellings of lifetime sales must weigh the same');
  assert.strictEqual(trendingScore.sellerStrengthOf({stats: null}, 0), 0);
  assert.strictEqual(trendingScore.sellerStrengthOf({stats: 7}, 0), 0);
});

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 7, 18, 12, 0, 0);

const ev = (over = {}) => ({
  userId: 'U1',
  type: 'view_detail',
  _eventMs: NOW,
  ...over,
});

const merge = (existing, events, hoursSinceLastRun = 6) =>
  tasteProfile.mergeProfile(existing, events, {nowMs: NOW, hoursSinceLastRun});

test('weightKeyOf refuses keys that would corrupt the map they land in', () => {
  assert.strictEqual(tasteProfile.weightKeyOf('__proto__'), '');
  assert.strictEqual(tasteProfile.weightKeyOf('constructor'), '');
  assert.strictEqual(tasteProfile.weightKeyOf('__anything__'), '');
  assert.strictEqual(tasteProfile.weightKeyOf('   '), '');
  assert.strictEqual(tasteProfile.weightKeyOf(null), '');
  assert.strictEqual(
      tasteProfile.weightKeyOf('x'.repeat(tasteProfile.MAX_KEY_LEN + 1)), '');
  assert.strictEqual(tasteProfile.weightKeyOf('  תל  אביב '), 'תל אביב');
});

test('a hostile key cannot pollute the profile it is merged into', () => {
  const p = merge(null, [ev({category: '__proto__', brand: '__proto__'})]);
  assert.deepStrictEqual(p.weights.categories, {});
  assert.deepStrictEqual(p.weights.brands, {});
  assert.strictEqual(
      Object.getPrototypeOf(p.weights.categories), Object.prototype);
});

test('brand keys fold case-insensitively into ONE bucket', () => {
  const p = merge(null, [
    ev({type: 'like', brand: 'Apple'}),
    ev({type: 'like', brand: 'apple'}),
    ev({type: 'like', brand: ' APPLE '}),
  ]);
  assert.deepStrictEqual(Object.keys(p.weights.brands), ['apple']);
  assert.ok(Math.abs(p.weights.brands.apple - 15) < 1e-6);
});

test('an EXISTING split profile self-heals on the next run, no migration', () => {
  const existing = {
    version: 2,
    weights: {
      categories: {},
      brands: {Apple: 24.75, apple: 16.22},
      sellers: {},
      priceBands: {},
    },
    totalSignals: 40,
  };
  const p = merge(existing, [ev({category: 'electronics'})]);
  assert.deepStrictEqual(Object.keys(p.weights.brands), ['apple']);
  const expected = (24.75 + 16.22) * tasteProfile.decayFactor(6);
  assert.ok(Math.abs(p.weights.brands.apple - expected) < 1e-3,
      `expected both halves summed then decayed, got ${p.weights.brands.apple}`);
});

test('computeAffinity finds a folded brand from an unfolded listing', () => {
  const profile = {
    weights: {categories: {}, brands: {apple: 40}, sellers: {}, priceBands: {}},
  };
  const legacyCasing = tasteProfile.computeAffinity(profile, {id: 'P1', brand: 'Apple'});
  const storedCasing = tasteProfile.computeAffinity(profile, {id: 'P1', brand: 'apple'});
  assert.ok(legacyCasing > 0, 'a legacy display-cased brand must still score');
  assert.strictEqual(legacyCasing, storedCasing);
});

test('computeAffinity reads a STILL-SPLIT profile at full strength', () => {
  const split = {
    weights: {categories: {}, brands: {Apple: 24.75, apple: 16.22},
      sellers: {}, priceBands: {}},
  };
  const healed = {
    weights: {categories: {}, brands: {apple: 24.75 + 16.22},
      sellers: {}, priceBands: {}},
  };
  const product = {id: 'P1', brand: 'Apple'};
  assert.strictEqual(
      tasteProfile.computeAffinity(split, product),
      tasteProfile.computeAffinity(healed, product),
      'a split profile must score the same as the merged one it will become');
});

test('a prototype-member key never produces NaN or a string weight', () => {
  const p = merge(null, [
    ev({type: 'like', brand: 'toString', category: 'valueOf',
      city: 'hasOwnProperty', subcategory: 'toLocaleString'}),
  ]);
  for (const axis of ['brands', 'categories', 'cities', 'subcategories']) {
    for (const [k, v] of Object.entries(p.weights[axis])) {
      assert.strictEqual(typeof v, 'number', `${axis}.${k} must be a number`);
      assert.ok(Number.isFinite(v), `${axis}.${k} must be finite`);
    }
  }
  assert.strictEqual(p.weights.brands.tostring, 5);

  const affinity = tasteProfile.computeAffinity(p, {
    id: 'P1', brand: 'toString', category: 'valueOf', price: 100,
  });
  assert.ok(Number.isFinite(affinity), `affinity must be a number, got ${affinity}`);
  assert.ok(affinity > 0, 'and the signal it really carries must still score');

  const cold = {weights: {categories: {electronics: 4}, brands: {lg: 2},
    sellers: {}, priceBands: {}}};
  const coldAffinity = tasteProfile.computeAffinity(
      cold, {id: 'P2', brand: 'toString', category: 'hasOwnProperty'});
  assert.strictEqual(coldAffinity, 0);
});

test('the product-attribute axes are learned from the widened event', () => {
  const p = merge(null, [
    ev({type: 'like', category: 'electronics', condition: 'likeNew',
      subcategory: 'mobilePhones', city: 'תל אביב', isBargain: true, price: 900}),
    ev({type: 'view_detail', category: 'electronics', condition: 'fair',
      subcategory: 'laptops', city: 'חיפה', isBargain: false, price: 900}),
  ]);
  assert.ok(p.weights.conditions.likeNew > p.weights.conditions.fair,
      'a like must outweigh a view on the condition axis, as everywhere else');
  assert.deepStrictEqual(
      Object.keys(p.weights.subcategories).sort(), ['laptops', 'mobilePhones']);
  assert.deepStrictEqual(Object.keys(p.weights.cities).sort(), ['חיפה', 'תל אביב']);
  assert.deepStrictEqual(p.weights.bargains, {bargain: 5, standard: 1.5});
  assert.strictEqual(
      p.weights.categories.electronics,
      p.weights.conditions.likeNew + p.weights.conditions.fair);
});

test('the new axes carry the same age decay as the existing ones', () => {
  const old = merge(null, [ev({type: 'like', condition: 'good', _eventMs: NOW - 20 * DAY_MS})]);
  const fresh = merge(null, [ev({type: 'like', condition: 'good'})]);
  assert.ok(old.weights.conditions.good < fresh.weights.conditions.good);
  assert.ok(
      Math.abs(old.weights.conditions.good - fresh.weights.conditions.good / Math.E) < 1e-3);
});

test('an event from before the widening contributes to the axes it HAS', () => {
  const legacy = ev({type: 'purchase', category: 'electronics', brand: 'LG',
    sellerId: 'S1', price: 250});
  const p = merge(null, [legacy]);
  assert.strictEqual(p.weights.categories.electronics, 10);
  assert.strictEqual(p.weights.brands.lg, 10);
  assert.strictEqual(p.weights.priceBands.b150_400, 10);
  assert.deepStrictEqual(p.weights.conditions, {});
  assert.deepStrictEqual(p.weights.subcategories, {});
  assert.deepStrictEqual(p.weights.cities, {});
  assert.deepStrictEqual(p.weights.bargains, {},
      'a missing isBargain must never be counted as "not a bargain"');
});

test('a profile written before the axes existed merges without a crash', () => {
  const existing = {
    version: 2,
    weights: {
      categories: {electronics: 12},
      brands: {lg: 4},
      sellers: {S1: 3},
      priceBands: {b150_400: 9},
    },
    recentSearches: [{q: 'מקרר', atMs: NOW - DAY_MS}],
    cartAdds: [],
    totalSignals: 31,
  };
  const p = merge(existing, [ev({type: 'like', condition: 'brandNew', city: 'רמת גן'})]);
  assert.strictEqual(p.weights.conditions.brandNew, 5);
  assert.strictEqual(p.weights.cities['רמת גן'], 5);
  assert.strictEqual(
      p.weights.categories.electronics,
      Math.round(12 * tasteProfile.decayFactor(6) * 1000) / 1000);
  assert.strictEqual(p.totalSignals, 32);
  assert.strictEqual(p.version, 2, 'additive axes must not bump the shape version');
});

test('the bargains axis records both sides, so the ratio is readable', () => {
  const p = merge(null, [
    ev({isBargain: false}),
    ev({isBargain: false}),
    ev({type: 'like', isBargain: true}),
  ]);
  assert.deepStrictEqual(p.weights.bargains, {bargain: 5, standard: 3});
});

test('open-ended axes are pruned, server-derived ones are not', () => {
  const events = [];
  for (let i = 0; i < 40; i++) events.push(ev({type: 'like', city: `city${i}`}));
  events.push(ev({isBargain: false, price: 10}));
  const p = merge(null, events);
  assert.strictEqual(Object.keys(p.weights.cities).length, 30);
  assert.ok(p.weights.bargains.standard > 0);
  assert.ok(p.weights.priceBands.b0_50 > 0);
});

test('an axis entry decayed to nothing is dropped, not kept as a zero', () => {
  const existing = {
    version: 2,
    weights: {
      categories: {}, brands: {}, sellers: {}, priceBands: {},
      conditions: {fair: 1e-9}, subcategories: {}, cities: {}, bargains: {},
    },
    totalSignals: 1,
  };
  const p = merge(existing, []);
  assert.deepStrictEqual(p.weights.conditions, {});
});

const storageUrls = require('../src/storageUrls');
const imageVariants = require('../src/imageVariants');

const BUCKET = storageUrls.STORAGE_BUCKET_FALLBACK;
const proofUrl = (objectPath, extra = '') =>
  `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/` +
  `${encodeURIComponent(objectPath)}?alt=media&token=abc-123${extra}`;

test('storageObjectPath decodes a firebasestorage.googleapis.com download URL', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(proofUrl('chat_attachments/C1/USER1/shot.jpg')),
      'chat_attachments/C1/USER1/shot.jpg');
});

test('storageObjectPath decodes the plain storage.googleapis.com form', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(
          `https://storage.googleapis.com/${BUCKET}/chat_attachments/C1/USER1/shot.jpg`),
      'chat_attachments/C1/USER1/shot.jpg');
});

test('storageObjectPath rejects a URL on some other bucket', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(
          'https://firebasestorage.googleapis.com/v0/b/attacker-bucket/o/' +
          `${encodeURIComponent('chat_attachments/C1/USER1/shot.jpg')}?alt=media`),
      null);
});

test('storageObjectPath rejects a URL on some other host entirely', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(
          `https://evil.example.com/chat_attachments/C1/USER1/shot.jpg`),
      null);
});

test('storageObjectPath rejects a host that merely STARTS WITH the real one', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(
          `https://firebasestorage.googleapis.com@evil.example.com/v0/b/${BUCKET}/o/x?alt=media`),
      null);
});

test('storageObjectPath rejects malformed percent-encoding rather than throwing', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(
          `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/%E0%A4%A`),
      null);
});

test('storageObjectPath rejects a path containing a ".." segment', () => {
  assert.strictEqual(
      storageUrls.storageObjectPath(proofUrl('chat_attachments/C1/USER1/../USER2/shot.jpg')),
      null);
});

test('storageObjectPath rejects garbage input rather than throwing', () => {
  assert.strictEqual(storageUrls.storageObjectPath(null), null);
  assert.strictEqual(storageUrls.storageObjectPath(undefined), null);
  assert.strictEqual(storageUrls.storageObjectPath(42), null);
  assert.strictEqual(storageUrls.storageObjectPath('not a url'), null);
});

test('objectBelongsToFolder accepts an object strictly inside the folder', () => {
  assert.strictEqual(
      storageUrls.objectBelongsToFolder(
          proofUrl('chat_attachments/C1/USER1/shot.jpg'), 'chat_attachments/C1/USER1/'),
      true);
});

test('objectBelongsToFolder rejects the bare folder itself (no object)', () => {
  assert.strictEqual(
      storageUrls.objectBelongsToFolder(
          proofUrl('chat_attachments/C1/USER1/'), 'chat_attachments/C1/USER1/'),
      false);
});

test('objectBelongsToFolder rejects a DIFFERENT chat\'s folder', () => {
  assert.strictEqual(
      storageUrls.objectBelongsToFolder(
          proofUrl('chat_attachments/C2/USER1/shot.jpg'), 'chat_attachments/C1/USER1/'),
      false);
});

test('objectBelongsToFolder rejects a DIFFERENT user\'s folder on the same chat', () => {
  assert.strictEqual(
      storageUrls.objectBelongsToFolder(
          proofUrl('chat_attachments/C1/USER2/shot.jpg'), 'chat_attachments/C1/USER1/'),
      false);
});

test('objectBelongsToFolder rejects the historical substring-match hole', () => {
  const foreignObject = 'chat_attachments/C9/USER9/other.jpg';
  const sneaky = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/` +
      `${encodeURIComponent(foreignObject)}?alt=media&x=chat_attachments/C1/USER1/`;
  assert.strictEqual(
      storageUrls.objectBelongsToFolder(sneaky, 'chat_attachments/C1/USER1/'),
      false);
});

test('objectBelongsToFolder rejects a non-string / empty input', () => {
  assert.strictEqual(storageUrls.objectBelongsToFolder(null, 'chat_attachments/C1/USER1/'), false);
  assert.strictEqual(storageUrls.objectBelongsToFolder('', 'chat_attachments/C1/USER1/'), false);
  assert.strictEqual(storageUrls.objectBelongsToFolder(123, 'chat_attachments/C1/USER1/'), false);
});

test('objectExistsInFolder resolves false for a structurally foreign URL, ' +
    'never reaching Storage', async () => {
  assert.strictEqual(
      await storageUrls.objectExistsInFolder(
          proofUrl('chat_attachments/C2/USER1/shot.jpg'), 'chat_attachments/C1/USER1/'),
      false);
});

test('objectExistsInFolder resolves false for garbage input', async () => {
  assert.strictEqual(
      await storageUrls.objectExistsInFolder(null, 'chat_attachments/C1/USER1/'), false);
  assert.strictEqual(
      await storageUrls.objectExistsInFolder(undefined, 'chat_attachments/C1/USER1/'), false);
});

test('parseResizedObjectPath recognises a thumb-sized resize output', () => {
  assert.deepStrictEqual(
      imageVariants.parseResizedObjectPath('product_images/SELLER1/1699_abc_600x600.jpg'),
      {originalPath: 'product_images/SELLER1/1699_abc.jpg', width: 600, height: 600});
});

test('parseResizedObjectPath recognises a medium-sized resize output', () => {
  assert.deepStrictEqual(
      imageVariants.parseResizedObjectPath('product_images/SELLER1/1699_abc_1280x1280.jpg'),
      {originalPath: 'product_images/SELLER1/1699_abc.jpg', width: 1280, height: 1280});
});

test('parseResizedObjectPath returns null for the original upload itself', () => {
  assert.strictEqual(
      imageVariants.parseResizedObjectPath('product_images/SELLER1/1699_abc.jpg'), null);
});

test('parseResizedObjectPath returns null outside product_images/', () => {
  assert.strictEqual(
      imageVariants.parseResizedObjectPath('chat_attachments/C1/USER1/shot_600x600.jpg'), null);
});

test('parseResizedObjectPath returns null for a size-looking but non-numeric suffix', () => {
  assert.strictEqual(
      imageVariants.parseResizedObjectPath('product_images/SELLER1/abc_WxH.jpg'), null);
});

test('parseResizedObjectPath handles a file with no extension', () => {
  assert.deepStrictEqual(
      imageVariants.parseResizedObjectPath('product_images/SELLER1/abc_600x600'),
      {originalPath: 'product_images/SELLER1/abc', width: 600, height: 600});
});

test('variantKeyFor maps the two configured sizes and nothing else', () => {
  assert.strictEqual(imageVariants.variantKeyFor(600, 600), 'thumb');
  assert.strictEqual(imageVariants.variantKeyFor(1280, 1280), 'medium');
  assert.strictEqual(imageVariants.variantKeyFor(200, 200), null);
  assert.strictEqual(imageVariants.variantKeyFor(600, 1280), null);
});

test('sellerUidFromProductImagePath reads the {uid} path segment', () => {
  assert.strictEqual(
      imageVariants.sellerUidFromProductImagePath('product_images/SELLER1/a.jpg'), 'SELLER1');
});

test('sellerUidFromProductImagePath is null for a malformed or foreign path', () => {
  assert.strictEqual(imageVariants.sellerUidFromProductImagePath('product_images/'), null);
  assert.strictEqual(imageVariants.sellerUidFromProductImagePath('other/SELLER1/a.jpg'), null);
});

test('downloadUrlFor produces the token-less shape the client validates against', () => {
  assert.strictEqual(
      imageVariants.downloadUrlFor('my-bucket', 'product_images/SELLER1/a_600x600.jpg'),
      'https://firebasestorage.googleapis.com/v0/b/my-bucket/o/' +
      'product_images%2FSELLER1%2Fa_600x600.jpg?alt=media');
});

test('mergeVariant adds a new entry for a photo with no prior variants', () => {
  const next = imageVariants.mergeVariant(undefined, 'https://orig/a.jpg', 'thumb', 'https://thumb/a.jpg');
  assert.deepStrictEqual(next, [{original: 'https://orig/a.jpg', thumb: 'https://thumb/a.jpg'}]);
});

test('mergeVariant fills in the SECOND size without clobbering the first', () => {
  const withThumb = [{original: 'https://orig/a.jpg', thumb: 'https://thumb/a.jpg'}];
  const next = imageVariants.mergeVariant(withThumb, 'https://orig/a.jpg', 'medium', 'https://medium/a.jpg');
  assert.deepStrictEqual(next, [{
    original: 'https://orig/a.jpg', thumb: 'https://thumb/a.jpg', medium: 'https://medium/a.jpg',
  }]);
});

test('mergeVariant leaves OTHER photos\' entries untouched', () => {
  const existing = [
    {original: 'https://orig/a.jpg', thumb: 'https://thumb/a.jpg'},
    {original: 'https://orig/b.jpg', thumb: 'https://thumb/b.jpg'},
  ];
  const next = imageVariants.mergeVariant(existing, 'https://orig/b.jpg', 'medium', 'https://medium/b.jpg');
  assert.deepStrictEqual(next, [
    {original: 'https://orig/a.jpg', thumb: 'https://thumb/a.jpg'},
    {original: 'https://orig/b.jpg', thumb: 'https://thumb/b.jpg', medium: 'https://medium/b.jpg'},
  ]);
});

test('modelMatchScore: same model, different phrasing → exact', () => {
  const r = _searchScoring.modelMatchScore('iphone 13', 'iPhone 13');
  assert.strictEqual(r.basis, 'exact');
  assert.strictEqual(r.score, _searchScoring.MODEL_SCORE_EXACT);
});

test('modelMatchScore: buyer model is a SUBSET of the stamped model → variant', () => {
  const r = _searchScoring.modelMatchScore('iphone 13', 'iPhone 13 Pro');
  assert.strictEqual(r.basis, 'variant');
  assert.strictEqual(r.score, _searchScoring.MODEL_SCORE_VARIANT);
});

test('modelMatchScore: stamped model is a SUBSET of the buyer model → generalized', () => {
  const r = _searchScoring.modelMatchScore('iphone 13 pro', 'iPhone 13');
  assert.strictEqual(r.basis, 'generalized');
  assert.strictEqual(r.score, _searchScoring.MODEL_SCORE_GENERALIZED);
});

test('modelMatchScore: iPhone 13 vs iPhone 15 is a CONFLICT, not a partial match ' +
    '— the exact pair that used to be indistinguishable', () => {
  const r = _searchScoring.modelMatchScore('iphone 13', 'iPhone 15');
  assert.strictEqual(r.basis, 'conflict');
  assert.strictEqual(r.score, 0);
});

test('modelMatchScore: a shared WORD token cannot rescue disjoint designators ' +
    '(the Jaccard trap)', () => {
  const r = _searchScoring.modelMatchScore('iphone 13', 'iPhone 15 Pro');
  assert.strictEqual(r.basis, 'conflict');
  assert.strictEqual(r.score, 0);
});

test('modelMatchScore: ps5 vs ps4 is a conflict', () => {
  const r = _searchScoring.modelMatchScore('ps5', 'ps4');
  assert.strictEqual(r.basis, 'conflict');
  assert.strictEqual(r.score, 0);
});

test('modelMatchScore: a short suffix code (iPhone X vs iPhone XS) is a conflict', () => {
  const r = _searchScoring.modelMatchScore('iphone x', 'iPhone XS');
  assert.strictEqual(r.basis, 'conflict');
  assert.strictEqual(r.score, 0);
});

test('modelMatchScore: the weight ladder — exact > variant > generalized > ' +
    'partial > conflict, and exact alone outweighs category+subcategory+brand combined', () => {
  const exact = _searchScoring.modelMatchScore('iphone 13', 'iPhone 13').score;
  const variant = _searchScoring.modelMatchScore('iphone 13', 'iPhone 13 Pro').score;
  const generalized = _searchScoring.modelMatchScore('iphone 13 pro', 'iPhone 13').score;
  const partial = _searchScoring.modelMatchScore('iphone 13', 'iPhone').score;
  const conflict = _searchScoring.modelMatchScore('iphone 13', 'iPhone 15').score;
  assert.ok(exact > variant, 'exact should outrank variant');
  assert.ok(variant > generalized, 'variant should outrank generalized');
  assert.ok(generalized > partial, 'generalized should outrank partial');
  assert.ok(partial > conflict, 'partial should outrank conflict');
  assert.ok(exact > 20 + 15 + 15,
      'model exact must outweigh category+subcategory+brand combined');
});

test('modelMatchScore: separator style never matters (collapse comparison)', () => {
  assert.strictEqual(_searchScoring.modelMatchScore('s24', 'S-24').basis, 'exact');
  assert.strictEqual(_searchScoring.modelMatchScore('iphone13', 'iPhone 13').basis, 'exact');
});

test('modelMatchScore: reuses signals.normalizeToken, not a local lowercase ' +
    '— ktiv male/haser spellings compare equal', () => {
  const r = _searchScoring.modelMatchScore('טלוויזיה', 'טלויזיה');
  assert.strictEqual(r.basis, 'exact');
});

test('modelMatchScore: a bare word-only stamped model ("iPhone") is a weak ' +
    'partial, not a generalized match — the seller never said which generation', () => {
  const r = _searchScoring.modelMatchScore('iphone 13', 'iPhone');
  assert.strictEqual(r.basis, 'partial');
  assert.strictEqual(r.score, 20);
});

test('modelMatchScore: an empty model on either side is inert ({0, "none"})', () => {
  assert.deepStrictEqual(_searchScoring.modelMatchScore('', 'iPhone 13'), {score: 0, basis: 'none'});
  assert.deepStrictEqual(_searchScoring.modelMatchScore('iphone 13', ''), {score: 0, basis: 'none'});
  assert.deepStrictEqual(_searchScoring.modelMatchScore(null, null), {score: 0, basis: 'none'});
});

test('modelMatchScore: hostile stamped-model input never throws and never scores', () => {
  const hostileValues = ['x'.repeat(300), {weird: 'object'}, [1, 2, 3], null, 42, undefined];
  for (const hostile of hostileValues) {
    assert.doesNotThrow(() => _searchScoring.modelMatchScore('iphone 13', hostile));
    assert.strictEqual(_searchScoring.modelMatchScore('iphone 13', hostile).score, 0);
  }
});

test('titleModelEvidence: a corroborated bare designator in the title scores ' +
    'title_designator — the cross-script case that needs no modelAliases array', () => {
  const r = _searchScoring.titleModelEvidence(
      'iphone 13', 'אייפון 13 פרו מקס 256 ג\'יגה', {corroborated: true});
  assert.strictEqual(r.basis, 'title_designator');
  assert.strictEqual(r.score, _searchScoring.MODEL_SCORE_TITLE_DESIGNATOR);
});

test('titleModelEvidence: the wrong generation in the title scores nothing', () => {
  const r = _searchScoring.titleModelEvidence(
      'iphone 15', 'אייפון 13 פרו מקס 256 ג\'יגה', {corroborated: true});
  assert.strictEqual(r.score, 0);
});

test('titleModelEvidence: an UNCORROBORATED bare designator scores nothing ' +
    '— a "13" next to "אמפר" is not evidence of a phone model', () => {
  const r = _searchScoring.titleModelEvidence(
      'iphone 13', 'אופניים חשמליים 13 אמפר', {corroborated: false});
  assert.strictEqual(r.score, 0);
  assert.strictEqual(r.basis, 'title_weak');
});

test('titleModelEvidence: only the TITLE is consulted — the function has no ' +
    'description parameter at all, so a description match is structurally impossible', () => {
  const r = _searchScoring.titleModelEvidence('iphone 13', 'אייפון', {corroborated: true});
  assert.strictEqual(r.score, 0);
});

test('modelSignalFor: a stamped model wins exclusively — a title trade-in ' +
    'mention cannot resurrect a conflict as a title match', () => {
  const product = {
    specificFields: {model: 'iPhone 15'},
    title: 'אייפון 15 מחליף אייפון 13',
  };
  const r = _searchScoring.modelSignalFor('iphone 13', product, {corroborated: true});
  assert.strictEqual(r.basis, 'conflict');
  assert.strictEqual(r.score, 0);
  assert.strictEqual(r.band, 0);
});

test('modelSignalFor: no stamped model falls back to the title', () => {
  const product = {title: 'אייפון 13 פרו מקס 256 ג\'יגה'};
  const r = _searchScoring.modelSignalFor('iphone 13', product, {corroborated: true});
  assert.strictEqual(r.basis, 'title_designator');
  assert.strictEqual(r.band, 1);
});

test('sanitizeSearchIntent: a model that just names the brand is dropped', () => {
  const r = _searchScoring.sanitizeSearchIntent(
      {model: 'apple', brand: 'apple', keywords: [], brandAliases: []}, 'apple phone');
  assert.strictEqual(r.model, null);
});

test('sanitizeSearchIntent: a hallucinated generation is dropped — the query ' +
    'never named one', () => {
  const r = _searchScoring.sanitizeSearchIntent(
      {model: 'iphone 15', brand: null, keywords: [], brandAliases: []}, 'אייפון');
  assert.strictEqual(r.model, null);
});

test('sanitizeSearchIntent: cross-script survival — the designator token ' +
    'is enough even though the word token never appears in the Hebrew query', () => {
  const r = _searchScoring.sanitizeSearchIntent(
      {model: 'iphone 13', brand: null, keywords: [], brandAliases: []}, 'אייפון 13');
  assert.strictEqual(r.model, 'iphone 13');
});

test('orderByModelBand: cannot lift a band-0 product above a band-2 product', () => {
  const products = [
    {id: 'weak', modelBand: 0}, {id: 'strong', modelBand: 2},
  ];
  const ordered = _searchScoring.orderByModelBand(products);
  assert.deepStrictEqual(ordered.map((p) => p.id), ['strong', 'weak']);
});

test('orderByModelBand: is a STABLE sort — two band-2 products keep the ' +
    'LLM\'s relative order', () => {
  const products = [
    {id: 'a', modelBand: 2}, {id: 'b', modelBand: 0},
    {id: 'c', modelBand: 2}, {id: 'd', modelBand: 1},
  ];
  const ordered = _searchScoring.orderByModelBand(products);
  assert.deepStrictEqual(ordered.map((p) => p.id), ['a', 'c', 'd', 'b']);
});

test('signals.productModelRaw reads specificFields.model, falls back to ' +
    'product.model, then \'\'', () => {
  assert.strictEqual(
      signals.productModelRaw({specificFields: {model: 'iPhone 13'}, model: 'ignored'}),
      'iPhone 13');
  assert.strictEqual(signals.productModelRaw({model: 'iPhone 13'}), 'iPhone 13');
  assert.strictEqual(signals.productModelRaw({}), '');
  assert.strictEqual(signals.productModelRaw(null), '');
});

test('priceKeyPartsFor is byte-identical after the productModelRaw refactor ' +
    '— aiSearch and the price_stats grouping ' +
    'must read the same field in the same order', () => {
  const priceKeyPartsFor = signals._signals.priceKeyPartsFor;
  const stamped = {
    brand: 'Apple', specificFields: {model: 'iPhone 13'},
    categoryId: 'electronics', subCategoryId: 'mobilePhones',
  };
  const modelFieldOnly = {
    brand: 'Apple', model: 'iPhone 13',
    category: 'electronics', subcategory: 'mobilePhones',
  };
  const modelLess = {
    brand: 'Apple', category: 'electronics', subcategory: 'mobilePhones',
  };
  const expected = {
    category: 'electronics', subcategory: 'mobilePhones',
    brand: 'apple', model: 'iphone 13',
  };
  assert.deepStrictEqual(priceKeyPartsFor(stamped), expected);
  assert.deepStrictEqual(priceKeyPartsFor(modelFieldOnly), expected);
  assert.deepStrictEqual(priceKeyPartsFor(modelLess),
      {category: 'electronics', subcategory: 'mobilePhones', brand: 'apple', model: ''});
});

test('REGION_ADJACENCY: every region is a key, symmetric, no self-edge, no ' +
    'region is isolated', () => {
  for (const region of israelRegions.REGIONS) {
    const neighbours = israelRegions.REGION_ADJACENCY[region];
    assert.ok(Array.isArray(neighbours), `${region} missing from REGION_ADJACENCY`);
    assert.ok(!neighbours.includes(region), `${region} is self-adjacent`);
    assert.ok(neighbours.length > 0, `${region} is isolated`);
  }
  for (const [region, neighbours] of Object.entries(israelRegions.REGION_ADJACENCY)) {
    for (const adj of neighbours) {
      assert.ok(israelRegions.REGION_ADJACENCY[adj].includes(region),
          `${region} -> ${adj} is not symmetric`);
    }
  }
});

test('regionOfCity: exact city names, Hebrew and English', () => {
  assert.strictEqual(israelRegions.regionOfCity('תל אביב-יפו'), 'gushDan');
  assert.strictEqual(israelRegions.regionOfCity('Tel Aviv'), 'gushDan');
  assert.strictEqual(israelRegions.regionOfCity('חיפה'), 'haifa');
});

test('regionOfCity: direction words resolve via tier-1 exact match', () => {
  assert.strictEqual(israelRegions.regionOfCity('המרכז'), 'gushDan');
  assert.strictEqual(israelRegions.regionOfCity('הצפון'), 'north');
  assert.strictEqual(israelRegions.regionOfCity('הדרום'), 'south');
});

test('regionOfCity: the tier-2 trap — "צפון תל אביב" is gushDan, not north', () => {
  assert.strictEqual(israelRegions.regionOfCity('צפון תל אביב'), 'gushDan');
});

test('regionOfCity: null/empty/unrecognised all return null', () => {
  assert.strictEqual(israelRegions.regionOfCity(null), null);
  assert.strictEqual(israelRegions.regionOfCity(''), null);
  assert.strictEqual(israelRegions.regionOfCity('פריז'), null);
});

test('regionsForSearchTerm: the three direction words widen to their ' +
    'plausible neighbouring set', () => {
  assert.deepStrictEqual(israelRegions.regionsForSearchTerm('המרכז'),
      new Set(['gushDan', 'hasharon', 'shfela']));
  assert.deepStrictEqual(israelRegions.regionsForSearchTerm('הצפון'),
      new Set(['north', 'haifa']));
  assert.deepStrictEqual(israelRegions.regionsForSearchTerm('הדרום'),
      new Set(['south']));
});

test('regionsForSearchTerm: a plain city name falls back to its single region', () => {
  assert.deepStrictEqual(israelRegions.regionsForSearchTerm('חיפה'), new Set(['haifa']));
  assert.deepStrictEqual(israelRegions.regionsForSearchTerm('פריז'), new Set());
});

test('region matching: "המרכז" now also matches חולון ' +
    '(previously invisible to the old ~8-city hardcoded list), and still ' +
    'does NOT match a באר שבע listing', () => {
  const regions = israelRegions.regionsForSearchTerm('המרכז');
  assert.ok(regions.has(israelRegions.regionOfCity('חולון')),
      'חולון should now be reachable from a "המרכז" search');
  assert.ok(!regions.has(israelRegions.regionOfCity('באר שבע')),
      'באר שבע must stay out of "המרכז"');
});

test('aiSearch.js\'s _searchScoring re-exports the SAME functions — the ' +
    'integration point unit.test.js can pin without duplicating the port', () => {
  assert.strictEqual(_searchScoring.regionOfCity, israelRegions.regionOfCity);
  assert.strictEqual(_searchScoring.regionsForSearchTerm, israelRegions.regionsForSearchTerm);
});

test('isGroqRateLimited recognises the exact shape callGroqAPI throws for a 429', () => {
  assert.strictEqual(
      _llm.isGroqRateLimited(new Error(
          'Groq API error: 429 - {"error":{"code":"rate_limit_exceeded"}}')),
      true);
});

test('isGroqRateLimited also matches a rate-limit message with a different status code', () => {
  assert.strictEqual(
      _llm.isGroqRateLimited(new Error('Groq API error: 503 - rate limit exceeded upstream')),
      true);
});

test('isGroqRateLimited is false for an unrelated Groq error', () => {
  assert.strictEqual(
      _llm.isGroqRateLimited(new Error('Groq API error: 400 - {"error":{"message":"bad request"}}')),
      false);
});

test('isGroqRateLimited is false for null/undefined/non-Error input', () => {
  assert.strictEqual(_llm.isGroqRateLimited(null), false);
  assert.strictEqual(_llm.isGroqRateLimited(undefined), false);
  assert.strictEqual(_llm.isGroqRateLimited({}), false);
});
