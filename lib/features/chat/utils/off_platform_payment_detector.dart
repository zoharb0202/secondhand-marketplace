library;

const String _hebrewPrefix = r'(?:[בולכמשה])?';
final List<RegExp> offPlatformPaymentHighConfidencePatterns = [
  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'ביט(?![א-ת])',
  ),
  RegExp(r'\bbit\s*(app|pay)\b', caseSensitive: false),

  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'פייבוקס(?![א-ת])',
  ),
  RegExp(r'\bpaybox\b', caseSensitive: false),

  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'העברה\s+בנקאית(?![א-ת])',
  ),
  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'העברת\s+כסף(?![א-ת])',
  ),
  RegExp(r'\bbank\s*transfer\b', caseSensitive: false),

  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'וואטסאפ(?![א-ת])',
  ),
  RegExp(
    '(?<![א-ת])$_hebrewPrefix'
    r'וטסאפ(?![א-ת])',
  ),
  RegExp(r'\bwhats\s*app\b', caseSensitive: false),

  RegExp(
    r'(?<![א-ת])מספר\s+טלפון(?![א-ת])[^\n]{0,40}?(לשלם|תשלום|שלם|העבר|העברה)',
  ),
  RegExp(
    r'(לשלם|תשלום|שלם|העבר|העברה)[^\n]{0,40}?(?<![א-ת])מספר\s+טלפון(?![א-ת])',
  ),

  RegExp(r'\biban\b', caseSensitive: false),
  RegExp(r'\bbic\b', caseSensitive: false),
];

final List<RegExp> offPlatformPaymentLowConfidencePatterns = [
  RegExp(r'(?<![א-ת])מזומן\s+בלבד(?![א-ת])'),
  RegExp(r'\bcash\s+only\b', caseSensitive: false),
];

List<RegExp> get offPlatformPaymentPatterns => [
  ...offPlatformPaymentHighConfidencePatterns,
  ...offPlatformPaymentLowConfidencePatterns,
];

bool containsOffPlatformPaymentMention(String text) {
  if (text.trim().isEmpty) return false;
  for (final pattern in offPlatformPaymentPatterns) {
    if (pattern.hasMatch(text)) return true;
  }
  return false;
}
