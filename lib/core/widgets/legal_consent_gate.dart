import 'package:flutter/material.dart';

import '../services/legal_consent_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';

class LegalConsentGate extends StatefulWidget {
  final Widget child;

  final LegalConsentService? service;

  const LegalConsentGate({super.key, required this.child, this.service});

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  late final LegalConsentService _service =
      widget.service ?? LegalConsentService();

  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    try {
      final status = await _service.status();
      if (!mounted || status.upToDate) return;
      await _promptUntilAccepted(status);
    } catch (_) {}
  }

  Future<void> _promptUntilAccepted(ConsentStatus status) async {
    while (mounted) {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _ConsentSheet(status: status, service: _service),
      );
      if (accepted == true) break;
      if (!mounted) break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentSheet extends StatefulWidget {
  final ConsentStatus status;
  final LegalConsentService service;

  const _ConsentSheet({required this.status, required this.service});

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  bool get _isUpdate => widget.status.isReacceptance;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.record(
        consentContext: _isUpdate ? 'reacceptance' : 'signup',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'לא הצלחנו לשמור את האישור. בדקו את החיבור ונסו שוב.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return PopScope(
      canPop: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + media.viewInsets.bottom + media.padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isUpdate
                    ? 'עדכנו את תנאי השימוש'
                    : 'תנאי השימוש ומדיניות הפרטיות',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                _isUpdate
                    ? 'פרסמנו גרסה חדשה. כדי להמשיך להשתמש באפליקציה יש לאשר אותה.'
                    : 'כדי להמשיך יש לאשר את תנאי השימוש ואת מדיניות הפרטיות.',
                style: TextStyle(fontSize: 14, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDocument(context, 'terms'),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('תנאי השימוש'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDocument(context, 'privacy'),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                      label: const Text('מדיניות פרטיות'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _agreed,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'קראתי ואני מאשר/ת את תנאי השימוש ואת מדיניות הפרטיות',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (!_agreed || _busy) ? null : _accept,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('אישור והמשך'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.of(context).pop(false);
                        Navigator.of(context).maybePop();
                      },
                child: Text(
                  'לא מאשר/ת כרגע',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocument(BuildContext context, String kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentPage(kind: kind, service: widget.service),
      ),
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  final String kind;
  final LegalConsentService? service;

  const LegalDocumentPage({super.key, required this.kind, this.service});

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final LegalConsentService _service =
      widget.service ?? LegalConsentService();
  late final Future<LegalDocument?> _future = _service.currentDocument(
    widget.kind,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind == 'terms' ? 'תנאי השימוש' : 'מדיניות פרטיות'),
      ),
      body: FutureBuilder<LegalDocument?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snapshot.data;
          if (doc == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'המסמך טרם פורסם.',
                  style: TextStyle(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  doc.title.isEmpty ? '—' : doc.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'גרסה ${doc.version}',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(
                  doc.body,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
