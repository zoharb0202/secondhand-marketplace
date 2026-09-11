import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<bool> hasBiometricsEnrolled() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      final canAuthenticate = await hasBiometricsEnrolled();
      if (!canAuthenticate) {
        return false;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == 'NotAvailable') {
        return false;
      } else if (e.code == 'NotEnrolled') {
        return false;
      } else if (e.code == 'LockedOut' || e.code == 'PermanentlyLockedOut') {
        return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String> getBiometricStatusMessage() async {
    final canCheck = await canUseBiometrics();
    if (!canCheck) {
      return 'המכשיר לא תומך באימות ביומטרי';
    }

    final isEnrolled = await hasBiometricsEnrolled();
    if (!isEnrolled) {
      return 'לא הוגדר אימות ביומטרי במכשיר';
    }

    final biometrics = await getAvailableBiometrics();
    if (biometrics.isNotEmpty) {
      return 'אימות ביומטרי זמין';
    }

    return 'אימות ביומטרי זמין';
  }
}
