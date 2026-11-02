import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/cache.dart';
import '../core/session.dart';

/// Offline cache and settings live in shared_preferences (private to this app).
class PrefsStore implements KeyValueStore {
  PrefsStore(this._p);
  final SharedPreferences _p;

  @override
  Future<String?> getString(String key) async => _p.getString('aaspaas.$key');

  @override
  Future<void> setString(String key, String value) async {
    await _p.setString('aaspaas.$key', value);
  }

  @override
  Future<void> remove(String key) async {
    await _p.remove('aaspaas.$key');
  }
}

/// The sign-in token goes in the phone's secure storage (Android Keystore), not in plain preferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore();
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _s.read(key: 'aaspaas_token');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _s.write(key: 'aaspaas_token', value: token);
    } catch (_) {
      // If secure storage fails the person simply has to sign in again next time.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _s.delete(key: 'aaspaas_token');
    } catch (_) {}
  }
}
