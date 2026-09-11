import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';

class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _passwordController = TextEditingController();
  final _confirmTextController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isDeleting = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmTextController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_agreedToTerms) {
      setState(() {
        _errorMessage = 'יש לאשר את תנאי המחיקה';
      });
      return;
    }

    if (_confirmTextController.text != 'מחק את החשבון שלי') {
      setState(() {
        _errorMessage = 'יש להקליד בדיוק: מחק את החשבון שלי';
      });
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('משתמש לא מחובר');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      await FirebaseFunctions.instance
          .httpsCallable(
            'deleteUserAccount',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call();

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ref.read(routerProvider).go('/login');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('החשבון נמחק בהצלחה'),
          backgroundColor: AppColors.success,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'הסיסמה שגויה';
          break;
        case 'requires-recent-login':
          errorMessage = 'יש להתחבר מחדש כדי למחוק את החשבון';
          break;
        default:
          errorMessage = 'שגיאה: ${e.message}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMessage = 'שגיאה במחיקת החשבון: ${e.message ?? e.code}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'אירעה שגיאה: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('מחיקת חשבון')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.warning_rounded, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'אזהרה: פעולה בלתי הפיכה',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'מחיקת החשבון תמחק לצמיתות את כל הנתונים שלך:',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _InfoItem(
              icon: Icons.person_off,
              title: 'פרופיל המשתמש',
              description: 'שם, אימייל, מספר טלפון ופרטים אישיים',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.inventory_2_outlined,
              title: 'כל המוצרים שלך',
              description: 'כולל תמונות ותיאורים',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.shopping_bag_outlined,
              title: 'היסטוריית הזמנות',
              description: 'רכישות ומכירות',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.chat_bubble_outline,
              title: 'הודעות ושיחות',
              description: 'כל ההתכתבויות שלך',
            ),
            const SizedBox(height: 12),
            _InfoItem(
              icon: Icons.star_outline,
              title: 'ביקורות ודירוגים',
              description: 'שניתנו על ידך ועליך',
            ),
            const SizedBox(height: 32),

            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              },
              title: const Text(
                'אני מבין שפעולה זו בלתי הפיכה וכל המידע שלי יימחק לצמיתות',
                style: TextStyle(fontSize: 14),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'הזן את הסיסמה שלך לאישור',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmTextController,
              decoration: const InputDecoration(
                labelText: 'הקלד: מחק את החשבון שלי',
                prefixIcon: Icon(Icons.edit_outlined),
                helperText: 'יש להקליד בדיוק את הטקסט המבוקש',
              ),
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            ElevatedButton(
              onPressed: _isDeleting ? null : _deleteAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'מחק את החשבון שלי לצמיתות',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: _isDeleting
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('ביטול'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.error, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
