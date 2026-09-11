library;

enum IsraelRegion {
  gushDan,
  hasharon,
  shfela,
  jerusalem,
  haifa,
  north,
  south;

  String get hebrewLabel {
    switch (this) {
      case IsraelRegion.gushDan:
        return 'גוש דן';
      case IsraelRegion.hasharon:
        return 'השרון';
      case IsraelRegion.shfela:
        return 'השפלה';
      case IsraelRegion.jerusalem:
        return 'ירושלים והסביבה';
      case IsraelRegion.haifa:
        return 'חיפה והקריות';
      case IsraelRegion.north:
        return 'הצפון';
      case IsraelRegion.south:
        return 'הדרום';
    }
  }
}

const Map<IsraelRegion, List<String>> regionCityAliases = {
  IsraelRegion.gushDan: [
    'תל אביב-יפו',
    'תל אביב',
    'יפו',
    'tel aviv',
    'רמת גן',
    'ramat gan',
    'גבעתיים',
    'givatayim',
    'בני ברק',
    'bnei brak',
    'חולון',
    'holon',
    'בת ים',
    'bat yam',
    'אור יהודה',
    'or yehuda',
    'קרית אונו',
    'kiryat ono',
    'גבעת שמואל',
    'גני תקווה',
    'יהוד-מונוסון',
    'יהוד',
    'סביון',
    'פתח תקווה',
    'פתח תקוה',
    'petah tikva',
    'petach tikva',
    'ראש העין',
    'rosh haayin',
    'ראשון לציון',
    'rishon lezion',
    'rishon',
    'הרצליה',
    'herzliya',
    'herzelia',
    'רמת השרון',
    'ramat hasharon',
  ],
  IsraelRegion.hasharon: [
    'נתניה',
    'netanya',
    'כפר סבא',
    'kfar saba',
    'רעננה',
    'raanana',
    'הוד השרון',
    'hod hasharon',
    'אבן יהודה',
    'תל מונד',
    'כפר יונה',
    'טירה',
    'טייבה',
    'קלנסווה',
    'פרדס חנה-כרכור',
    'פרדס חנה',
    'חדרה',
    'hadera',
    'בנימינה',
    'זכרון יעקב',
    'אור עקיבא',
    'קיסריה',
  ],
  IsraelRegion.shfela: [
    'רחובות',
    'rehovot',
    'נס ציונה',
    'ness ziona',
    'יבנה',
    'yavne',
    'לוד',
    'lod',
    'רמלה',
    'ramla',
    'מודיעין-מכבים-רעות',
    'מודיעין',
    'modiin',
    'גדרה',
    'גן יבנה',
    'קרית עקרון',
    'מזכרת בתיה',
    'באר יעקב',
    'שוהם',
    'shoham',
    'אלעד',
  ],
  IsraelRegion.jerusalem: [
    'ירושלים',
    'jerusalem',
    'בית שמש',
    'beit shemesh',
    'מעלה אדומים',
    'ביתר עילית',
    'מבשרת ציון',
    'גבעת זאב',
    'צור הדסה',
    'אפרת',
    'אבו גוש',
  ],
  IsraelRegion.haifa: [
    'חיפה',
    'haifa',
    'קרית ביאליק',
    'קרית מוצקין',
    'קרית ים',
    'קרית אתא',
    'הקריות',
    'קריות',
    'נשר',
    'nesher',
    'טירת כרמל',
    'רכסים',
  ],
  IsraelRegion.north: [
    'נצרת עילית',
    'נוף הגליל',
    'נצרת',
    'nazareth',
    'עפולה',
    'afula',
    'טבריה',
    'tiberias',
    'צפת',
    'safed',
    'tzfat',
    'כרמיאל',
    'karmiel',
    'נהריה',
    'nahariya',
    'עכו',
    'akko',
    'acre',
    'מגדל העמק',
    'בית שאן',
    'קרית שמונה',
    'מעלות-תרשיחא',
    'מעלות',
    'שפרעם',
    'סחנין',
    'טמרה',
    'יקנעם עילית',
    'יקנעם',
    'קצרין',
    'אום אל פחם',
  ],
  IsraelRegion.south: [
    'באר שבע',
    'beer sheva',
    'beersheba',
    'אשדוד',
    'ashdod',
    'אשקלון',
    'ashkelon',
    'קרית גת',
    'kiryat gat',
    'קרית מלאכי',
    'אופקים',
    'נתיבות',
    'שדרות',
    'sderot',
    'דימונה',
    'dimona',
    'ערד',
    'arad',
    'אילת',
    'eilat',
    'מצפה רמון',
    'ירוחם',
    'רהט',
    'להבים',
    'עומר',
    'מיתר',
  ],
};

const Map<String, IsraelRegion> _directionWordRegion = {
  'המרכז': IsraelRegion.gushDan,
  'מרכז': IsraelRegion.gushDan,
  'center': IsraelRegion.gushDan,
  'הצפון': IsraelRegion.north,
  'צפון': IsraelRegion.north,
  'north': IsraelRegion.north,
  'גליל': IsraelRegion.north,
  'הדרום': IsraelRegion.south,
  'דרום': IsraelRegion.south,
  'south': IsraelRegion.south,
  'נגב': IsraelRegion.south,
};

String _norm(String? s) {
  if (s == null) return '';
  return s.trim().toLowerCase().replaceAll(RegExp(r'''[\s\-'"׳״]'''), '');
}

final Map<String, IsraelRegion> _normalizedDirectionWords = {
  for (final e in _directionWordRegion.entries) _norm(e.key): e.value,
};

final List<MapEntry<String, IsraelRegion>> _normalizedCityAliases = () {
  final out = <MapEntry<String, IsraelRegion>>[];
  regionCityAliases.forEach((region, names) {
    for (final name in names) {
      final n = _norm(name);
      if (n.isNotEmpty) out.add(MapEntry(n, region));
    }
  });
  out.sort((a, b) => b.key.length.compareTo(a.key.length));
  return out;
}();

final Map<String, IsraelRegion> _exactCityAliasRegion = {
  for (final e in _normalizedCityAliases) e.key: e.value,
};

IsraelRegion? israelRegionOf(String? cityOrAddress) {
  final k = _norm(cityOrAddress);
  if (k.isEmpty) return null;

  final exact = _normalizedDirectionWords[k] ?? _exactCityAliasRegion[k];
  if (exact != null) return exact;

  for (final alias in _normalizedCityAliases) {
    if (k.contains(alias.key)) return alias.value;
  }
  return null;
}

const double kAdjacentBorrow = 0.3;

const Map<IsraelRegion, Set<IsraelRegion>> regionAdjacency = {
  IsraelRegion.gushDan: {IsraelRegion.hasharon, IsraelRegion.shfela},
  IsraelRegion.hasharon: {IsraelRegion.gushDan, IsraelRegion.haifa},
  IsraelRegion.shfela: {
    IsraelRegion.gushDan,
    IsraelRegion.jerusalem,
    IsraelRegion.south,
  },
  IsraelRegion.jerusalem: {IsraelRegion.shfela, IsraelRegion.south},
  IsraelRegion.haifa: {IsraelRegion.hasharon, IsraelRegion.north},
  IsraelRegion.north: {IsraelRegion.haifa},
  IsraelRegion.south: {IsraelRegion.shfela, IsraelRegion.jerusalem},
};
