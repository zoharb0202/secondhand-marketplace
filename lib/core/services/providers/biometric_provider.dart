import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../biometric_service.dart';
import '../secure_storage_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final biometricAvailabilityProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(biometricServiceProvider);
  return await service.hasBiometricsEnrolled();
});

final hasStoredCredentialsProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageServiceProvider);
  return await storage.hasCredentials();
});

final biometricLoginEnabledProvider =
    StateNotifierProvider<BiometricLoginNotifier, bool>((ref) {
      return BiometricLoginNotifier();
    });

class BiometricLoginNotifier extends StateNotifier<bool> {
  static const String _key = 'biometric_login_enabled';

  BiometricLoginNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = enabled;
  }

  Future<void> disable() async {
    await setEnabled(false);
  }
}
