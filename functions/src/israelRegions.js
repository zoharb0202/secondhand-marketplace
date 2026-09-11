const REGIONS = [
  'gushDan', 'hasharon', 'shfela', 'jerusalem', 'haifa', 'north', 'south',
];

const REGION_CITY_ALIASES = {
  gushDan: [
    'תל אביב-יפו', 'תל אביב', 'יפו', 'tel aviv',
    'רמת גן', 'ramat gan',
    'גבעתיים', 'givatayim',
    'בני ברק', 'bnei brak',
    'חולון', 'holon',
    'בת ים', 'bat yam',
    'אור יהודה', 'or yehuda',
    'קרית אונו', 'kiryat ono',
    'גבעת שמואל',
    'גני תקווה',
    'יהוד-מונוסון', 'יהוד',
    'סביון',
    'פתח תקווה', 'פתח תקוה', 'petah tikva', 'petach tikva',
    'ראש העין', 'rosh haayin',
    'ראשון לציון', 'rishon lezion', 'rishon',
    'הרצליה', 'herzliya', 'herzelia',
    'רמת השרון', 'ramat hasharon',
  ],
  hasharon: [
    'נתניה', 'netanya',
    'כפר סבא', 'kfar saba',
    'רעננה', 'raanana',
    'הוד השרון', 'hod hasharon',
    'אבן יהודה',
    'תל מונד',
    'כפר יונה',
    'טירה',
    'טייבה',
    'קלנסווה',
    'פרדס חנה-כרכור', 'פרדס חנה',
    'חדרה', 'hadera',
    'בנימינה',
    'זכרון יעקב',
    'אור עקיבא',
    'קיסריה',
  ],
  shfela: [
    'רחובות', 'rehovot',
    'נס ציונה', 'ness ziona',
    'יבנה', 'yavne',
    'לוד', 'lod',
    'רמלה', 'ramla',
    'מודיעין-מכבים-רעות', 'מודיעין', 'modiin',
    'גדרה',
    'גן יבנה',
    'קרית עקרון',
    'מזכרת בתיה',
    'באר יעקב',
    'שוהם', 'shoham',
    'אלעד',
  ],
  jerusalem: [
    'ירושלים', 'jerusalem',
    'בית שמש', 'beit shemesh',
    'מעלה אדומים',
    'ביתר עילית',
    'מבשרת ציון',
    'גבעת זאב',
    'צור הדסה',
    'אפרת',
    'אבו גוש',
  ],
  haifa: [
    'חיפה', 'haifa',
    'קרית ביאליק',
    'קרית מוצקין',
    'קרית ים',
    'קרית אתא',
    'הקריות', 'קריות',
    'נשר', 'nesher',
    'טירת כרמל',
    'רכסים',
  ],
  north: [
    'נצרת עילית', 'נוף הגליל',
    'נצרת', 'nazareth',
    'עפולה', 'afula',
    'טבריה', 'tiberias',
    'צפת', 'safed', 'tzfat',
    'כרמיאל', 'karmiel',
    'נהריה', 'nahariya',
    'עכו', 'akko', 'acre',
    'מגדל העמק',
    'בית שאן',
    'קרית שמונה',
    'מעלות-תרשיחא', 'מעלות',
    'שפרעם',
    'סחנין',
    'טמרה',
    'יקנעם עילית', 'יקנעם',
    'קצרין',
    'אום אל פחם',
  ],
  south: [
    'באר שבע', 'beer sheva', 'beersheba',
    'אשדוד', 'ashdod',
    'אשקלון', 'ashkelon',
    'קרית גת', 'kiryat gat',
    'קרית מלאכי',
    'אופקים',
    'נתיבות',
    'שדרות', 'sderot',
    'דימונה', 'dimona',
    'ערד', 'arad',
    'אילת', 'eilat',
    'מצפה רמון',
    'ירוחם',
    'רהט',
    'להבים',
    'עומר',
    'מיתר',
  ],
};

const DIRECTION_WORD_REGION = {
  'המרכז': 'gushDan', 'מרכז': 'gushDan', 'center': 'gushDan',
  'הצפון': 'north', 'צפון': 'north', 'north': 'north', 'גליל': 'north',
  'הדרום': 'south', 'דרום': 'south', 'south': 'south', 'נגב': 'south',
};

function _norm(s) {
  if (s == null) return '';
  return String(s).trim().toLowerCase().replace(/[\s\-'"׳״]/g, '');
}

const _normalizedDirectionWords = (() => {
  const out = {};
  for (const [k, v] of Object.entries(DIRECTION_WORD_REGION)) out[_norm(k)] = v;
  return out;
})();

const _normalizedCityAliases = (() => {
  const out = [];
  for (const [region, names] of Object.entries(REGION_CITY_ALIASES)) {
    for (const name of names) {
      const n = _norm(name);
      if (n) out.push([n, region]);
    }
  }
  out.sort((a, b) => b[0].length - a[0].length);
  return out;
})();

const _exactCityAliasRegion = (() => {
  const out = {};
  for (const [alias, region] of _normalizedCityAliases) out[alias] = region;
  return out;
})();

function regionOfCity(cityOrAddress) {
  const k = _norm(cityOrAddress);
  if (!k) return null;

  const exact = _normalizedDirectionWords[k] || _exactCityAliasRegion[k];
  if (exact) return exact;

  for (const [alias, region] of _normalizedCityAliases) {
    if (k.includes(alias)) return region;
  }
  return null;
}

const REGION_ADJACENCY = {
  gushDan: ['hasharon', 'shfela'],
  hasharon: ['gushDan', 'haifa'],
  shfela: ['gushDan', 'jerusalem', 'south'],
  jerusalem: ['shfela', 'south'],
  haifa: ['hasharon', 'north'],
  north: ['haifa'],
  south: ['shfela', 'jerusalem'],
};

const K_ADJACENT_BORROW = 0.3;

function regionsForSearchTerm(term) {
  const norm = _norm(term);
  if (!norm) return new Set();
  if (norm === _norm('המרכז') || norm === _norm('מרכז') || norm === _norm('center')) {
    return new Set(['gushDan', 'hasharon', 'shfela']);
  }
  if (norm === _norm('הצפון') || norm === _norm('צפון') || norm === _norm('north') ||
      norm === _norm('גליל')) {
    return new Set(['north', 'haifa']);
  }
  if (norm === _norm('הדרום') || norm === _norm('דרום') || norm === _norm('south') ||
      norm === _norm('נגב')) {
    return new Set(['south']);
  }
  const region = regionOfCity(term);
  return region ? new Set([region]) : new Set();
}

module.exports = {
  REGIONS,
  REGION_CITY_ALIASES,
  REGION_ADJACENCY,
  K_ADJACENT_BORROW,
  regionOfCity,
  regionsForSearchTerm,
};
