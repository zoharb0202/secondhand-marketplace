import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/widgets/animated_gradient.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../core/services/providers/biometric_provider.dart';
import '../../../support/presentation/pages/contact_support_page.dart';
import '../../../support/presentation/pages/admin_support_panel.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'change_password_page.dart';
import 'delete_account_page.dart';
import 'notification_settings_page.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      appBar: AppBar(
        title: GradientText(
          'הגדרות',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),

          _buildSectionCard(
            title: 'התראות',
            icon: Icons.notifications_outlined,
            gradient: AppColors.luxuryGradient3,
            delay: 0,
            children: [
              _buildNavTile(
                icon: Icons.notifications_active_outlined,
                title: 'העדפות התראות',
                subtitle: 'נהל התראות פוש, מייל ועדכוני הזמנות',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            title: 'אבטחה',
            icon: Icons.shield_outlined,
            gradient: AppColors.luxuryGradient1,
            delay: 1,
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final biometricAvailable = ref.watch(
                    biometricAvailabilityProvider,
                  );
                  final biometricEnabled = ref.watch(
                    biometricLoginEnabledProvider,
                  );
                  final user = ref.watch(currentUserProvider).value;

                  return biometricAvailable.when(
                    data: (isAvailable) {
                      if (!isAvailable || user == null) {
                        return _buildListTile(
                          icon: Icons.fingerprint,
                          title: 'זיהוי ביומטרי',
                          subtitle: 'לא זמין במכשיר זה',
                          enabled: false,
                        );
                      }

                      return _buildSwitchTile(
                        title: 'התחבר באמצעות זיהוי ביומטרי',
                        subtitle: biometricEnabled
                            ? 'מופעל - השתמש בטביעת אצבע או זיהוי פנים'
                            : 'כבוי - התחבר עם אימייל וסיסמה',
                        icon: Icons.fingerprint,
                        value: biometricEnabled,
                        onChanged: (value) async {
                          if (value) {
                            await _enableBiometricLogin(ref);
                          } else {
                            await _disableBiometricLogin(ref);
                          }
                        },
                      );
                    },
                    loading: () => _buildListTile(
                      icon: Icons.fingerprint,
                      title: 'זיהוי ביומטרי',
                      subtitle: 'טוען...',
                      enabled: false,
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            title: 'פרטיות',
            icon: Icons.privacy_tip_outlined,
            gradient: AppColors.luxuryGradient4,
            delay: 2,
            children: [
              _buildNavTile(
                icon: Icons.description_outlined,
                title: 'מדיניות פרטיות',
                onTap: () async {
                  final uri = Uri.parse(AppConstants.privacyUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              _buildDivider(),
              _buildNavTile(
                icon: Icons.gavel_outlined,
                title: 'תנאי שימוש',
                onTap: () async {
                  final uri = Uri.parse(AppConstants.termsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            title: 'עזרה ותמיכה',
            icon: Icons.support_agent_outlined,
            gradient: AppColors.luxuryGradient2,
            delay: 3,
            children: [
              _buildNavTile(
                icon: Icons.headset_mic_outlined,
                title: 'פנייה לשירות לקוחות',
                subtitle: 'יש לך שאלה או בעיה? נשמח לעזור',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContactSupportPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSectionCard(
            title: 'חשבון',
            icon: Icons.person_outline,
            gradient: AppColors.luxuryGradient1,
            delay: 5,
            children: [
              _buildNavTile(
                icon: Icons.lock_outline,
                title: 'שנה סיסמה',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage(),
                    ),
                  );
                },
              ),
              _buildDivider(),
              _buildNavTile(
                icon: Icons.download_outlined,
                title: 'ייצא נתונים',
                subtitle: 'הורד העתק של כל המידע שלך',
                onTap: () => _exportUserData(),
              ),
              _buildDivider(),
              _buildNavTile(
                icon: Icons.delete_outline,
                title: 'מחק חשבון',
                titleColor: AppColors.error,
                iconColor: AppColors.error,
                onTap: () => _showDeleteAccountDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (ref.watch(currentUserProvider).value?.isAdmin ?? false)
            _buildSectionCard(
              title: 'אדמין',
              icon: Icons.admin_panel_settings_outlined,
              gradient: AppColors.luxuryGradient2,
              delay: 6,
              children: [
                _buildNavTile(
                  icon: Icons.support_agent,
                  title: 'פאנל שירות לקוחות',
                  subtitle: 'נהל פניות לקוחות',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminSupportPanel(),
                      ),
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),

          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.altSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'גרסה 1.0.0',
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required LinearGradient gradient,
    required int delay,
    required List<Widget> children,
  }) {
    return Container(
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              ...children,
              const SizedBox(height: 8),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (80 * delay).ms, duration: 400.ms)
        .moveY(begin: 12, end: 0, delay: (80 * delay).ms, duration: 400.ms);
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SwitchListTile(
        secondary: icon != null
            ? Icon(icon, color: context.textSecondary, size: 22)
            : null,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              )
            : null,
        value: value,
        onChanged: onChanged,
        activeTrackColor: context.accentCobalt.withValues(alpha: 0.5),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return context.accentCobalt;
          }
          return null;
        }),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? context.textSecondary : context.textTertiary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: enabled ? context.textPrimary : context.textTertiary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              )
            : null,
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? context.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: titleColor ?? context.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: iconColor ?? context.textTertiary,
          size: 20,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            context.hairline.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
    );
  }

  Future<void> _exportUserData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppColors.premiumShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: context.accentCobalt,
                  strokeWidth: 2.5,
                ),
                const SizedBox(height: 16),
                Text(
                  'מייצא נתונים...',
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );

      final firestore = FirebaseFirestore.instance;
      final Map<String, dynamic> exportData = {};

      final userDoc = await firestore.collection('users').doc(user.id).get();
      exportData['profile'] = userDoc.data();

      final productsSnapshot = await firestore
          .collection('products')
          .where('sellerId', isEqualTo: user.id)
          .get();
      exportData['products'] = productsSnapshot.docs
          .map((d) => d.data())
          .toList();

      final ordersSnapshot = await firestore
          .collection('orders')
          .where('buyerId', isEqualTo: user.id)
          .get();
      exportData['orders'] = ordersSnapshot.docs.map((d) => d.data()).toList();

      final reviewsSnapshot = await firestore
          .collection('seller_reviews')
          .where('reviewerId', isEqualTo: user.id)
          .get();
      exportData['reviews'] = reviewsSnapshot.docs
          .map((d) => d.data())
          .toList();

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (mounted) Navigator.pop(context);

      await Share.share(
        jsonString,
        subject: 'הנתונים שלי מ-${AppConstants.appName}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('הנתונים יוצאו בהצלחה'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בייצוא נתונים: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _enableBiometricLogin(WidgetRef ref) async {
    final biometricService = ref.read(biometricServiceProvider);
    final secureStorage = ref.read(secureStorageServiceProvider);
    final user = ref.read(currentUserProvider).value;

    if (user?.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('לא ניתן להפעיל זיהוי ביומטרי ללא אימייל'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    try {
      final authenticated = await biometricService.authenticate(
        reason: 'אמת את זהותך כדי להפעיל זיהוי ביומטרי',
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('האימות הביומטרי נכשל'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        final password = await showDialog<String>(
          context: context,
          builder: (context) => const _PasswordDialog(),
        );

        if (password == null || password.isEmpty) {
          return;
        }

        await secureStorage.saveCredentials(
          email: user!.email,
          password: password,
        );

        await ref.read(biometricLoginEnabledProvider.notifier).setEnabled(true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('זיהוי ביומטרי הופעל בהצלחה'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בהפעלת זיהוי ביומטרי: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _disableBiometricLogin(WidgetRef ref) async {
    final secureStorage = ref.read(secureStorageServiceProvider);

    try {
      await secureStorage.deleteCredentials();

      await ref.read(biometricLoginEnabledProvider.notifier).setEnabled(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('זיהוי ביומטרי כבוי'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('שגיאה בכיבוי זיהוי ביומטרי: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const GradientText(
        'הזן סיסמה',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'כדי להפעיל זיהוי ביומטרי, הזן את הסיסמה שלך. הסיסמה תישמר באופן מאובטח במכשיר.',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'סיסמה',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ביטול'),
        ),
        GradientButton(
          text: 'אישור',
          onPressed: () {
            Navigator.pop(context, _passwordController.text);
          },
          height: 40,
          borderRadius: 12,
        ),
      ],
    );
  }
}
