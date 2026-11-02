// Who is signed in. Keeps the token in secure storage and the profile in the offline cache.
import 'dart:convert';
import 'api_client.dart';
import 'cache.dart';
import 'models.dart';
import 'repository.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

class Session {
  Session(
    this.api,
    this.tokens,
    this.cache,
    this.repo, {
    this.deviceName = 'App',
  });
  final ApiClient api;
  final TokenStore tokens;
  final JsonCache cache;
  final Repository repo;
  final String deviceName;

  AppUser? user;
  bool get loggedIn => user != null;

  /// Called at app start. A phone without internet stays signed in using the saved profile.
  Future<void> restore() async {
    final t = await tokens.read();
    if (t == null || t.isEmpty) return;
    api.token = t;
    try {
      final j = await api.get('/me');
      user = AppUser.fromJson(Map<String, dynamic>.from(j as Map));
      await cache.put('user', j);
    } on ApiException catch (e) {
      if (e.isNetwork) {
        final c = await cache.get('user');
        if (c != null && c.data is Map)
          user = AppUser.fromJson(Map<String, dynamic>.from(c.data as Map));
        if (user == null) api.token = null; // cannot tell who this is yet
      } else if (e.isAuth) {
        await _forget();
      } else {
        rethrow;
      }
    }
  }

  Future<AppUser> login(String email, String password) async {
    final j = await api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password, 'device': deviceName},
    );
    final m = Map<String, dynamic>.from(j as Map);
    final token = m['token'].toString();
    api.token = token;
    await tokens.write(token);
    user = AppUser.fromJson(Map<String, dynamic>.from(m['user'] as Map));
    await cache.put('user', m['user']);
    return user!;
  }

  /// Creates the account. The person must open the email link before they can sign in.
  Future<String> register({
    required String name,
    required String email,
    required String password,
    String type = 'customer',
    String phone = '',
    int area = 0,
  }) async {
    final j = await api.post(
      '/auth/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'type': type,
        'phone': phone.trim(),
        'area': area,
      },
    );
    return (j is Map ? j['message'] : null)?.toString() ??
        'Account created. Please check your email.';
  }

  Future<String> resend(String email) async {
    final j = await api.post('/auth/resend', body: {'email': email.trim()});
    return (j is Map ? j['message'] : null)?.toString() ??
        'Verification email sent.';
  }

  Future<void> logout() async {
    try {
      await api.post('/auth/logout');
    } on ApiException {
      // The token is dropped on this phone either way.
    }
    await _forget();
  }

  /// Google Play requires a way to delete the account inside the app.
  Future<void> deleteAccount(String password) async {
    await api.delete('/me', body: {'password': password});
    await _forget();
  }

  /// Local sign-out after the server says the token is no longer valid.
  Future<void> expire() => _forget();

  Future<void> _forget() async {
    user = null;
    api.token = null;
    await tokens.clear();
    await repo.clearPersonalData();
  }

  /// Not used by the app; handy for debugging a stored profile.
  String describe() => jsonEncode({'loggedIn': loggedIn, 'user': user?.email});
}
