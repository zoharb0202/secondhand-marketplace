import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/pages/add_first_address_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import 'legal_consent_gate.dart';
import 'main_navigation.dart';

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userModel = ref.watch(currentUserProvider).value;
    if (userModel != null && !userModel.isActive) {
      return const _SuspendedAccountScreen();
    }

    final addressesAsync = ref.watch(savedAddressesProvider(authUser.uid));

    return LegalConsentGate(
      child: addressesAsync.when(
        data: (addresses) => addresses.isEmpty
            ? const AddFirstAddressPage()
            : const MainNavigation(),
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, __) {
          if (kDebugMode) {
            debugPrint(
              '⚠️ [HOME_GATE] addresses read failed for '
              '${authUser.uid}: $error',
            );
          }
          return const MainNavigation();
        },
      ),
    );
  }
}

class _SuspendedAccountScreen extends StatefulWidget {
  const _SuspendedAccountScreen();

  @override
  State<_SuspendedAccountScreen> createState() =>
      _SuspendedAccountScreenState();
}

class _SuspendedAccountScreenState extends State<_SuspendedAccountScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 72, color: AppColors.error),
                const SizedBox(height: 24),
                Text(
                  'החשבון שלך הושעה. פנה לתמיכה.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'אם לדעתך מדובר בטעות, אנא צור קשר עם צוות התמיכה.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: context.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
