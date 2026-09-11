import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _dismissed = false;
  bool _sending = false;
  DateTime? _lastSentAt;

  Future<void> _resend(User user) async {
    final lastSentAt = _lastSentAt;
    if (lastSentAt != null &&
        DateTime.now().difference(lastSentAt) < const Duration(seconds: 60)) {
      _showSnack('כבר נשלח לאחרונה — נסו שוב בעוד רגע', AppColors.warning);
      return;
    }

    setState(() => _sending = true);
    try {
      await user.sendEmailVerification();
      _lastSentAt = DateTime.now();
      if (mounted) _showSnack('אימייל אימות נשלח מחדש', AppColors.success);
    } catch (e) {
      if (mounted) {
        _showSnack('שליחת האימייל נכשלה, נסו שוב מאוחר יותר', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;

    final isPasswordAccount =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;

    if (_dismissed ||
        user == null ||
        user.emailVerified ||
        !isPasswordAccount) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'לא אימתתם את כתובת האימייל שלכם',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              TextButton(
                onPressed: _sending ? null : () => _resend(user),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'שלח שוב',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              Semantics(
                label: 'סגור',
                button: true,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _dismissed = true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
