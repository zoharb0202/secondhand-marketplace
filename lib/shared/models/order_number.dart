library;

const String orderNumberLabelHe = 'מספר הזמנה';

const String _lri = '\u{2066}';
const String _pdi = '\u{2069}';

String? orderNumberDisplay(String? orderNumber) {
  final trimmed = orderNumber?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return '$_lri$trimmed$_pdi';
}
