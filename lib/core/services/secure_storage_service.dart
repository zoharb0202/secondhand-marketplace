import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _emailKey = 'biometric_email';
  static const String _passwordKey = 'biometric_password';

  Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<String?> getSavedEmail() async {
    return await _storage.read(key: _emailKey);
  }

  Future<String?> getSavedPassword() async {
    return await _storage.read(key: _passwordKey);
  }

  Future<bool> hasCredentials() async {
    final email = await getSavedEmail();
    final password = await getSavedPassword();
    return email != null && password != null;
  }

  Future<void> deleteCredentials() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
