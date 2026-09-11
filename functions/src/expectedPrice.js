const MIN_CONDITION_SAMPLES = 3;

const WINDOW_DAYS = 365;

const CONDITION_LADDER = ['new', 'likeNew', 'good', 'fair', 'forParts'];

function median(nums) {
  if (!nums || nums.length === 0) return null;
  const s = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : Math.round((s[mid - 1] + s[mid]) / 2);
}

function percentile(nums, p) {
  if (!nums || nums.length === 0) return null;
  const s = [...nums].sort((a, b) => a - b);
  const idx = Math.min(s.length - 1, Math.max(0, Math.round((s.length - 1) * p)));
  return s[idx];
}

function daysBetweenKeys(a, b) {
  if (!a || !b) return Number.MAX_SAFE_INTEGER;
  const da = new Date(`${a}T00:00:00Z`).getTime();
  const db = new Date(`${b}T00:00:00Z`).getTime();
  if (!Number.isFinite(da) || !Number.isFinite(db)) return Number.MAX_SAFE_INTEGER;
  return Math.abs(Math.round((da - db) / 86400000));
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function summarise(samples) {
  const prices = samples.map((s) => Number(s.p)).filter((n) => n > 0);
  if (prices.length === 0) return null;
  return {
    expected: median(prices),
    p25: percentile(prices, 0.25),
    p75: percentile(prices, 0.75),
    sampleSize: prices.length,
  };
}

async function expectedPriceFor(db, keyHash, condition) {
  const snap = await db.collection('price_stats').doc(keyHash).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  const all = Array.isArray(data.samples) ? data.samples : [];

  const today = todayKey();
  const fresh = all.filter((s) => daysBetweenKeys(today, s.d) <= WINDOW_DAYS);
  if (fresh.length === 0) return null;

  const blended = summarise(fresh);

  const byCondition = {};
  for (const cond of CONDITION_LADDER) {
    const bucket = fresh.filter((s) => s.cond === cond);
    const summary = summarise(bucket);
    if (summary && summary.sampleSize >= MIN_CONDITION_SAMPLES) {
      byCondition[cond] = {...summary, basis: 'condition'};
    }
  }

  let answer = null;
  let basis = null;

  if (condition && byCondition[condition]) {
    answer = byCondition[condition];
    basis = 'condition';
  } else if (condition) {
    const i = CONDITION_LADDER.indexOf(condition);
    if (i !== -1) {
      const neighbours = fresh.filter((s) => {
        const j = CONDITION_LADDER.indexOf(s.cond);
        return j !== -1 && Math.abs(j - i) <= 1;
      });
      const summary = summarise(neighbours);
      if (summary && summary.sampleSize >= MIN_CONDITION_SAMPLES) {
        answer = {...summary, basis: 'adjacent_conditions'};
        basis = 'adjacent_conditions';
      }
    }
  }

  if (!answer) {
    answer = blended ? {...blended, basis: 'all_conditions'} : null;
    basis = 'all_conditions';
  }

  if (!answer) return null;

  return {
    keyHash,
    category: data.category || null,
    subcategory: data.subcategory || null,
    brand: data.brand || null,
    model: data.model || null,
    condition: condition || null,
    expected: answer.expected,
    rangeLow: answer.p25,
    rangeHigh: answer.p75,
    sampleSize: answer.sampleSize,
    basis,
    windowDays: WINDOW_DAYS,
    byCondition,
    medianDaysToSell: (() => {
      const dts = fresh.map((s) => Number(s.dts)).filter((n) => Number.isFinite(n));
      return dts.length >= 3 ? median(dts) : null;
    })(),
  };
}

module.exports = {
  MIN_CONDITION_SAMPLES,
  WINDOW_DAYS,
  CONDITION_LADDER,
  median,
  percentile,
  daysBetweenKeys,
  summarise,
  expectedPriceFor,
};
