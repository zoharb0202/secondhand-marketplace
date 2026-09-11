import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const String _kAiMetricsCollection = 'ai_usage';
const String _kAiSummaryDoc = 'summary';

const String _kAiDailyCollection = 'ai_usage_daily';

const int _kMinRateN = 10;

const int _kWindow7 = 7;
const int _kWindow30 = 30;

enum _AiWindow { day, d7, d30 }

extension on _AiWindow {
  String get label => switch (this) {
    _AiWindow.day => 'יום אחרון',
    _AiWindow.d7 => '7 ימים',
    _AiWindow.d30 => '30 ימים',
  };

  String? get windowKey => switch (this) {
    _AiWindow.day => null,
    _AiWindow.d7 => 'd$_kWindow7',
    _AiWindow.d30 => 'd$_kWindow30',
  };
}

const Map<String, String> _kFeatureLabels = {
  'alert_match': 'התאמת מוצר להתראות',
  'ai_search': 'חיפוש חכם',
  'analyze_image': 'ניתוח תמונת מוצר',
  'recommendations': 'המלצות אישיות',
  'moderate_image': 'סינון תמונות',
  'chatbot': 'צ׳אט תמיכה',
  'create_smart_alert': 'יצירת התראה חכמה',
  'enhance_description': 'שיפור תיאור מוצר',
  'photo_quality': 'איכות צילום',
  'retail_estimate_llm': 'הערכת מחיר קמעונאי',
  'brand_verify': 'אימות מותג',
  'unknown': 'לא מזוהה',
};

const Map<String, String> _kFeatureHints = {
  'alert_match': 'טריגר על כל מוצר חדש — רץ בלי שאף אחד לחץ על משהו',
  'analyze_image': 'ראייה: Gemini, ואם הוא נופל — qwen',
  'moderate_image': 'ראייה: רץ על כל תמונה שמועלית',
  'photo_quality': 'ראייה',
  'retail_estimate_llm': 'תקציב גלובלי, לא לפי משתמש',
  'unknown': 'שם פיצ׳ר שלא קיים ב-AiFeature — כנראה שגיאת כתיב באתר קריאה',
};

const Set<String> _kVisionFeatures = {
  'analyze_image',
  'moderate_image',
  'photo_quality',
};

const Map<String, String> _kOutcomeLabels = {
  'ok': 'הצליח',
  'parse_failure': 'לא נפרסר',
  'schema_invalid': 'לא תאם לסכמה',
  'rate_limited': 'נחסם על קצב',
  'timeout': 'פסק זמן',
  'provider_error': 'שגיאת ספק',
  'safety_refusal': 'סירוב בטיחות',
};

const List<String> _kFailureOrder = [
  'parse_failure',
  'schema_invalid',
  'rate_limited',
  'timeout',
  'provider_error',
  'safety_refusal',
];

const List<FontFeature> _kTabular = [FontFeature.tabularFigures()];

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{};

int _int(Object? v) => v is num ? v.toInt() : 0;

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  return null;
}

String _fmtInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

String _fmtPct(Object? rate) {
  if (rate is! num) return '—';
  final p = rate * 100;
  if (p > 0 && p < 10) return '${p.toStringAsFixed(1)}%';
  return '${p.round()}%';
}

String _fmtShare(int part, int whole) {
  if (whole <= 0) return '—';
  final p = part * 100 / whole;
  if (p > 0 && p < 10) return '${p.toStringAsFixed(1)}%';
  return '${p.round()}%';
}

String _fmtMs(Object? ms) {
  if (ms is! num) return '—';
  final v = ms.toDouble();
  if (v < 1000) return '${v.round()} מ״ש';
  if (v < 10000) return '${(v / 1000).toStringAsFixed(1)} שנ׳';
  return '${(v / 1000).round()} שנ׳';
}

String _fmtTokens(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 10000) return '${(n / 1000).round()}K';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return _fmtInt(n);
}

String _featureLabel(String key) => _kFeatureLabels[key] ?? key;

String _fmtDateTime(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _fmtDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return key;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

class AiUsagePage extends StatelessWidget {
  const AiUsagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [AiUsageCard()],
    );
  }
}

class AiUsageCard extends StatefulWidget {
  const AiUsageCard({super.key});

  @override
  State<AiUsageCard> createState() => _AiUsageCardState();
}

class _AiUsageCardState extends State<AiUsageCard> {
  _AiWindow _window = _AiWindow.d7;
  bool _refreshing = false;

  Future<void> _recompute() async {
    setState(() => _refreshing = true);
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('recomputeAiUsage')
          .call<dynamic>();
      final data = _map(res.data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'חושב מחדש: ${_fmtInt(_int(data['countedEvents']))} '
            'קריאות נספרו, ${_fmtInt(_int(data['excludedEvents']))} הוחרגו',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'החישוב נכשל'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('שגיאה: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(_kAiMetricsCollection)
          .doc(_kAiSummaryDoc)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AiPlaceholder(
            icon: Icons.error_outline,
            title: 'שגיאה בטעינת מדדי ה-AI',
            body: '${snapshot.error}',
            refreshing: _refreshing,
            onRefresh: _refreshing ? null : _recompute,
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;
        if (!doc.exists) {
          return _AiPlaceholder(
            icon: Icons.hourglass_empty,
            title: 'מדדי ה-AI עוד לא חושבו',
            body:
                'החישוב רץ אוטומטית כל 6 שעות מרגע שיומן קריאות ה-AI הופעל. '
                'אפשר להריץ אותו עכשיו.',
            refreshing: _refreshing,
            onRefresh: _refreshing ? null : _recompute,
          );
        }

        final data = _map(doc.data());

        if (_int(data['countedEvents']) == 0) {
          return _AiPlaceholder(
            icon: Icons.sensors_off_outlined,
            title: 'עוד לא נרשמה אף קריאת AI',
            body:
                'יומן הקריאות מתחיל להתמלא ברגע שגרסה עם aiTelemetry עולה '
                'לאוויר ומגיעה תנועה אמיתית. עד אז אין כאן מספרים להראות — '
                'ובכוונה לא אפסים.',
            refreshing: _refreshing,
            onRefresh: _refreshing ? null : _recompute,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiHeader(
              data: data,
              window: _window,
              refreshing: _refreshing,
              onWindowChanged: (w) => setState(() => _window = w),
              onRefresh: _refreshing ? null : _recompute,
            ),
            const SizedBox(height: 12),
            _AiTrustBanners(data: data),
            if (_window == _AiWindow.day)
              const _AiDayWindow()
            else
              _fixedWindow(data),
            const SizedBox(height: 20),
            _AiFootnote(data: data),
          ],
        );
      },
    );
  }

  Widget _fixedWindow(Map<String, dynamic> data) {
    final key = _window.windowKey;
    final window = key == null
        ? const <String, dynamic>{}
        : _map(_map(data['windows'])[key]);
    if (window.isEmpty) {
      return const _EmptyWindowNote(
        text:
            'אין נתונים לחלון הזמן הזה. ייתכן שהחישוב האחרון רץ לפני שהחלון '
            'הזה הוגדר.',
      );
    }
    return _AiWindowBody(
      overall: _map(window['overall']),
      features: _map(window['features']),
    );
  }
}

class _AiHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  final _AiWindow window;
  final bool refreshing;
  final ValueChanged<_AiWindow> onWindowChanged;
  final VoidCallback? onRefresh;

  const _AiHeader({
    required this.data,
    required this.window,
    required this.refreshing,
    required this.onWindowChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final computedAt = _date(data['computedAt']) ?? _date(data['computedAtMs']);
    final earliest = _date(data['earliestEventMs']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'שימוש ב-AI',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              tooltip: 'חשב מחדש',
              onPressed: onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          'עודכן: ${_fmtDateTime(computedAt)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (earliest != null)
          Text(
            'הנתונים מתחילים ב־${_fmtDate(earliest)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final w in _AiWindow.values)
              FilterChip(
                label: Text(w.label),
                selected: window == w,
                onSelected: (_) => onWindowChanged(w),
              ),
          ],
        ),
      ],
    );
  }
}

class _AiTrustBanners extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AiTrustBanners({required this.data});

  @override
  Widget build(BuildContext context) {
    final banners = <Widget>[];

    if (data['testExclusionConfigured'] != true) {
      banners.add(
        const _WarnBanner(
          color: AppColors.warning,
          icon: Icons.science_outlined,
          text:
              'לא הוגדרה רשימת חשבונות בדיקה, כך שהמספרים עשויים לכלול תנועת '
              'פיתוח. יש ליצור מסמך ai_usage/config עם השדה excludedUserIds '
              '(רשימת מזהי משתמשים).',
        ),
      );
    }
    if (data['truncated'] == true) {
      banners.add(
        const _WarnBanner(
          color: AppColors.error,
          icon: Icons.content_cut,
          text:
              'סריקת היומן נקטעה באמצע — החלון שמוצג חלקי ואינו מייצג את כל '
              'התקופה.',
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: banners),
    );
  }
}

class _AiDayWindow extends StatelessWidget {
  const _AiDayWindow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(_kAiDailyCollection)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EmptyWindowNote(
            text: 'שגיאה בטעינת היום האחרון: ${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyWindowNote(
            text:
                'עוד לא נכתב אף סיכום יומי. הוא נוצר בהרצה הראשונה של החישוב '
                'שאחרי הקריאה הראשונה.',
          );
        }

        final doc = docs.first;
        final data = _map(doc.data());
        final key = (data['date'] is String) ? data['date'] as String : doc.id;

        return _AiWindowBody(
          overall: _map(data['overall']),
          features: _map(data['features']),
          note: 'יום מלא לפי שעון ישראל: ${_fmtDayKey(key)}',
        );
      },
    );
  }
}

class _FeatureRow {
  final String feature;
  final Map<String, dynamic> bucket;
  final int calls;

  const _FeatureRow(this.feature, this.bucket, this.calls);
}

class _AiWindowBody extends StatelessWidget {
  final Map<String, dynamic> overall;
  final Map<String, dynamic> features;
  final String? note;

  const _AiWindowBody({
    required this.overall,
    required this.features,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final total = _int(overall['calls']);
    if (total == 0) {
      return _EmptyWindowNote(
        text: note == null
            ? 'אין קריאות AI בחלון הזה.'
            : '$note\nאין קריאות AI בחלון הזה.',
      );
    }

    final rows = <_FeatureRow>[];
    features.forEach((key, value) {
      final bucket = _map(value);
      final calls = _int(bucket['calls']);
      if (calls > 0) rows.add(_FeatureRow(key, bucket, calls));
    });
    rows.sort((a, b) {
      final byCalls = b.calls.compareTo(a.calls);
      return byCalls != 0 ? byCalls : a.feature.compareTo(b.feature);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _AiHeadline(overall: overall),
        const SizedBox(height: 12),
        _BadShapeStrip(overall: overall),
        if (rows.isNotEmpty) ...[
          _ConcentrationBanner(top: rows.first, rows: rows, total: total),
          const SizedBox(height: 8),
          const Text(
            'לפי נפח, מהגבוה לנמוך',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            _FeatureCard(rank: i + 1, row: rows[i], total: total),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _AiHeadline extends StatelessWidget {
  final Map<String, dynamic> overall;

  const _AiHeadline({required this.overall});

  @override
  Widget build(BuildContext context) {
    final calls = _int(overall['calls']);
    final outcomes = _map(overall['outcomes']);
    final ok = _int(outcomes['ok']);
    final badShape = _map(overall['badShape']);
    final bad = _int(badShape['count']);
    final tokens = _map(overall['tokens']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _Cell(label: 'קריאות', value: _fmtInt(calls)),
                _Cell(
                  label: 'הצליחו',
                  value: _fmtPct(overall['okRate']),
                  sub: '${_fmtInt(ok)} מתוך ${_fmtInt(calls)}',
                  color: AppColors.success,
                ),
                _Cell(
                  label: 'תשובות פסולות',
                  value: _fmtPct(badShape['rate']),
                  sub: '${_fmtInt(bad)} קריאות',
                  color: bad > 0 ? AppColors.error : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _Cell(
                  label: 'זמן חציוני',
                  value: _fmtMs(_map(overall['latencyMs'])['p50']),
                  sub: 'p95 ${_fmtMs(_map(overall['latencyMs'])['p95'])}',
                ),
                _Cell(
                  label: 'טוקנים',
                  value: _fmtTokens(_int(tokens['total'])),
                  sub:
                      'נמדדו ב-${_fmtInt(_int(tokens['measuredCalls']))} קריאות',
                ),
                _Cell(
                  label: 'נחסמו על קצב',
                  value: _fmtInt(_int(outcomes['rate_limited'])),
                  color: _int(outcomes['rate_limited']) > 0
                      ? AppColors.warning
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BadShapeStrip extends StatelessWidget {
  final Map<String, dynamic> overall;

  const _BadShapeStrip({required this.overall});

  @override
  Widget build(BuildContext context) {
    final badShape = _map(overall['badShape']);
    final count = _int(badShape['count']);
    if (count == 0) return const SizedBox.shrink();

    final outcomes = _map(overall['outcomes']);
    final parse = _int(outcomes['parse_failure']);
    final schema = _int(outcomes['schema_invalid']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_gmailerrorred, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_fmtInt(count)} תשובות שלא ניתן היה להשתמש בהן '
                  '(${_fmtPct(badShape['rate'])})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontFeatures: _kTabular,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmtInt(parse)} לא נפרסרו · ${_fmtInt(schema)} לא תאמו '
                  'לסכמה. המודל ענה, הקריאה עלתה טוקנים, והתשובה נזרקה — זה '
                  'הסימן הישיר שהפרומפט (או הסכמה) לא עובד.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcentrationBanner extends StatelessWidget {
  final _FeatureRow top;
  final List<_FeatureRow> rows;
  final int total;

  const _ConcentrationBanner({
    required this.top,
    required this.rows,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total < _kMinRateN) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'מעט מדי קריאות בחלון הזה מכדי לדבר על ריכוז שימוש.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    final share = top.calls / total;
    final rest = total - top.calls;
    final dominant = share >= 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                dominant ? 'כאן מרוכז השימוש' : 'הפיצ׳ר הפעיל ביותר',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_featureLabel(top.feature)} — ${_fmtShare(top.calls, total)} '
            'מכלל קריאות ה-AI',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFeatures: _kTabular,
            ),
          ),
          const SizedBox(height: 6),
          _ShareBar(fraction: share, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            rows.length == 1
                ? '${_fmtInt(top.calls)} קריאות — זה הפיצ׳ר היחיד שרץ בחלון הזה'
                : '${_fmtInt(top.calls)} מתוך ${_fmtInt(total)} קריאות · '
                      'כל שאר ${rows.length - 1} הפיצ׳רים יחד: ${_fmtInt(rest)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFeatures: _kTabular,
            ),
          ),
          if (_kFeatureHints.containsKey(top.feature)) ...[
            const SizedBox(height: 4),
            Text(
              _kFeatureHints[top.feature]!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
          if (dominant) ...[
            const SizedBox(height: 6),
            const Text(
              'שיפור כאן שווה יותר מכל שאר הפיצ׳רים יחד — וגם כל ייקור כאן '
              'עולה יותר מכולם יחד.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final int rank;
  final _FeatureRow row;
  final int total;

  const _FeatureCard({
    required this.rank,
    required this.row,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final b = row.bucket;
    final calls = row.calls;
    final outcomes = _map(b['outcomes']);
    final badShape = _map(b['badShape']);
    final bad = _int(badShape['count']);
    final latency = _map(b['latencyMs']);
    final tokens = _map(b['tokens']);
    final fallbacks = _int(b['fallbacks']);
    final hint = _kFeatureHints[row.feature];
    final unknownFeature = row.feature == 'unknown';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank.',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textTertiary,
                    fontFeatures: _kTabular,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _featureLabel(row.feature),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: unknownFeature ? AppColors.error : null,
                        ),
                      ),
                      if (hint != null)
                        Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtInt(calls),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFeatures: _kTabular,
                      ),
                    ),
                    Text(
                      _fmtShare(calls, total),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontFeatures: _kTabular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ShareBar(
              fraction: total > 0 ? calls / total : 0,
              color: unknownFeature ? AppColors.error : AppColors.primary,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _Cell(
                  label: 'הצליחו',
                  value: _fmtPct(b['okRate']),
                  sub:
                      '${_fmtInt(_int(outcomes['ok']))} מתוך ${_fmtInt(calls)}',
                  color: AppColors.success,
                ),
                _Cell(
                  label: 'תשובות פסולות',
                  value: _fmtPct(badShape['rate']),
                  sub: bad == 0
                      ? 'אין'
                      : '${_fmtInt(_int(outcomes['parse_failure']))} פרסינג · '
                            '${_fmtInt(_int(outcomes['schema_invalid']))} סכמה',
                  color: bad > 0 ? AppColors.error : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _Cell(
                  label: 'זמן p50 / p95',
                  value:
                      '${_fmtMs(latency['p50'])} / ${_fmtMs(latency['p95'])}',
                  sub: 'n=${_fmtInt(_int(latency['n']))}',
                ),
                _Cell(
                  label: 'טוקנים',
                  value: _fmtTokens(_int(tokens['total'])),
                  sub: _int(tokens['unmeasuredCalls']) > 0
                      ? '${_fmtInt(_int(tokens['unmeasuredCalls']))} קריאות '
                            'בלי מדידה'
                      : 'נמדדו בכל הקריאות',
                ),
              ],
            ),
            if (_kVisionFeatures.contains(row.feature) || fallbacks > 0) ...[
              const SizedBox(height: 10),
              Text(
                fallbacks == 0
                    ? 'נפילה לספק גיבוי: לא קרה — הספק הראשון ענה בכל הקריאות'
                    : 'נפילה לספק גיבוי: ${_fmtInt(fallbacks)} קריאות '
                          '(${_fmtPct(b['fallbackRate'])}) — הספק הראשון נכשל '
                          'והשני ענה',
                style: TextStyle(
                  fontSize: 12,
                  color: fallbacks > 0
                      ? AppColors.warning
                      : AppColors.textSecondary,
                  fontFeatures: _kTabular,
                ),
              ),
            ],
            if (_int(b['cacheHits']) > 0) ...[
              const SizedBox(height: 6),
              Text(
                'נענו מהמטמון: ${_fmtInt(_int(b['cacheHits']))} '
                '(${_fmtPct(b['cacheHitRate'])}) — לא נכללות במדידת הזמן',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFeatures: _kTabular,
                ),
              ),
            ],
            _FailureChips(outcomes: outcomes),
            _PromptVersions(byPromptVersion: _map(b['byPromptVersion'])),
          ],
        ),
      ),
    );
  }
}

class _FailureChips extends StatelessWidget {
  final Map<String, dynamic> outcomes;

  const _FailureChips({required this.outcomes});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final key in _kFailureOrder) {
      final n = _int(outcomes[key]);
      if (n == 0) continue;
      final severe = key == 'parse_failure' || key == 'schema_invalid';
      chips.add(
        _Chip(
          text: '${_kOutcomeLabels[key] ?? key} ${_fmtInt(n)}',
          color: severe ? AppColors.error : AppColors.warning,
        ),
      );
    }
    outcomes.forEach((key, value) {
      if (key == 'ok' || _kFailureOrder.contains(key)) return;
      final n = _int(value);
      if (n > 0) {
        chips.add(_Chip(text: '$key ${_fmtInt(n)}', color: AppColors.warning));
      }
    });

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }
}

class _PromptVersions extends StatelessWidget {
  final Map<String, dynamic> byPromptVersion;

  const _PromptVersions({required this.byPromptVersion});

  @override
  Widget build(BuildContext context) {
    if (byPromptVersion.isEmpty) return const SizedBox.shrink();

    final entries =
        byPromptVersion.entries
            .map((e) => MapEntry(e.key, _map(e.value)))
            .toList()
          ..sort(
            (a, b) => _int(b.value['calls']).compareTo(_int(a.value['calls'])),
          );

    final anyBad = entries.any(
      (e) =>
          _int(e.value['parseFailures']) + _int(e.value['schemaInvalid']) > 0,
    );
    if (entries.length < 2 && !anyBad) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text(
            'לפי גרסת פרומפט',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(e.key, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_fmtInt(_int(e.value['calls']))} קריאות · '
                    '${_fmtPct(e.value['okRate'])} הצליחו',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontFeatures: _kTabular,
                    ),
                  ),
                  if (_int(e.value['parseFailures']) +
                          _int(e.value['schemaInvalid']) >
                      0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${_fmtInt(_int(e.value['parseFailures']) + _int(e.value['schemaInvalid']))} פסולות',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontFeatures: _kTabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AiFootnote extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AiFootnote({required this.data});

  @override
  Widget build(BuildContext context) {
    final excluded = _int(data['excludedEvents']);
    final counted = _int(data['countedEvents']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 10),
        Text(
          'המספרים מגיעים ממסמך אחד (ai_usage/summary) שמחושב מחדש כל 6 שעות. '
          'המסך הזה לא סורק את יומן הקריאות עצמו.\n'
          'אחוזים מוצגים רק כשיש לפחות $_kMinRateN קריאות, p50 דורש 5 מדידות '
          'ו-p95 דורש 20. "—" פירושו שהמדגם קטן מדי — לא אפס.\n'
          'קריאות שנענו מהמטמון לא נכללות במדידת הזמן.\n'
          '${_fmtInt(counted)} אירועים נספרו, ${_fmtInt(excluded)} הוחרגו '
          'כחשבונות בדיקה.',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? color;

  const _Cell({required this.label, required this.value, this.sub, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: _kTabular,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
                height: 1.3,
                fontFeatures: _kTabular,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareBar extends StatelessWidget {
  final double fraction;
  final Color color;

  const _ShareBar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 6,
        color: AppColors.border.withValues(alpha: 0.5),
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: f,
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;

  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFeatures: _kTabular,
        ),
      ),
    );
  }
}

class _WarnBanner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _WarnBanner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWindowNote extends StatelessWidget {
  final String text;

  const _EmptyWindowNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _AiPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool refreshing;
  final VoidCallback? onRefresh;

  const _AiPlaceholder({
    required this.icon,
    required this.title,
    required this.body,
    required this.refreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: refreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: const Text('חשב עכשיו'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
