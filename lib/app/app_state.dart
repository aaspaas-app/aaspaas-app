import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../core/cache.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../core/session.dart';

/// Everything the screens share: chosen area, signed-in person, favorites, GPS position, dismissed news.
class AppState extends ChangeNotifier {
  AppState({required this.repo, required this.session, required this.prefs});

  final Repository repo;
  final Session session;
  final KeyValueStore prefs;

  bool ready = false;
  Config? config;
  bool configFromCache = false;
  String? configError;

  int? areaId;
  double? lat;
  double? lng;
  Set<int> favoriteIds = <int>{};
  Set<String> seenNews = <String>{};

  AppUser? get user => session.user;
  bool get loggedIn => session.loggedIn;
  bool get hasLocation => lat != null && lng != null;

  Future<void> init() async {
    final a = await prefs.getString('area');
    areaId = int.tryParse(a ?? '');
    final n = await prefs.getString('news_seen');
    if (n != null) {
      try {
        seenNews = (jsonDecode(n) as List).map((e) => e.toString()).toSet();
      } catch (_) {}
    }
    try {
      await session.restore();
    } on ApiException {
      // Unexpected server answer: carry on as a visitor.
    }
    await loadConfig();
    if (areaId == null && user != null && user!.area > 0) {
      areaId = user!.area;
    }
    if (loggedIn) unawaited(refreshFavorites());
    ready = true;
    notifyListeners();
  }

  Future<void> loadConfig() async {
    try {
      final r = await repo.config();
      config = r.data;
      configFromCache = r.fromCache;
      configError = null;
    } on ApiException catch (e) {
      configError = e.message;
    }
    notifyListeners();
  }

  Term? get area => areaId == null ? null : config?.areaById(areaId!);

  String get areaLabel {
    final a = area;
    if (a == null) return 'Choose area';
    final c = config?.cityOf(a.id);
    return c == null ? a.name : '${a.name}, ${c.name}';
  }

  Future<void> setArea(int? id) async {
    areaId = (id == null || id <= 0) ? null : id;
    if (areaId == null) {
      await prefs.remove('area');
    } else {
      await prefs.setString('area', '$areaId');
    }
    notifyListeners();
  }

  /// Asks for the phone's position. Returns null when it worked, otherwise a message to show.
  Future<String?> useMyLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Please turn on location (GPS) on your phone.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return 'Location permission is off for this app.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not get your location. Please try again.';
    }
  }

  // ---------- favorites

  bool isFavorite(int id) => favoriteIds.contains(id);

  Future<void> refreshFavorites() async {
    try {
      final r = await repo.favorites();
      favoriteIds = r.data.map((e) => e.id).toSet();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isAuth) await handleAuthExpired();
    }
  }

  /// Returns a message to show when it did not work, or null on success.
  Future<String?> toggleFavorite(int id) async {
    if (!loggedIn) return 'Please log in to save favorites.';
    try {
      final saved = await repo.toggleFavorite(id);
      if (saved) {
        favoriteIds = {...favoriteIds, id};
      } else {
        favoriteIds = favoriteIds.where((e) => e != id).toSet();
      }
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      if (e.isAuth) {
        await handleAuthExpired();
        return 'Please log in again.';
      }
      return e.isNetwork ? 'You need internet to save favorites.' : e.message;
    }
  }

  // ---------- news the person has closed

  Future<void> dismissNews(NewsItem n) async {
    seenNews = {...seenNews, n.seenKey};
    final list = seenNews.toList();
    final keep = list.length > 100 ? list.sublist(list.length - 100) : list;
    await prefs.setString('news_seen', jsonEncode(keep));
    notifyListeners();
  }

  // ---------- accounts

  Future<void> login(String email, String password) async {
    await session.login(email, password);
    final u = user;
    if (areaId == null && u != null && u.area > 0) await setArea(u.area);
    notifyListeners();
    unawaited(refreshFavorites());
  }

  Future<String> register({
    required String name,
    required String email,
    required String password,
    required String type,
    String phone = '',
  }) {
    return session.register(
      name: name,
      email: email,
      password: password,
      type: type,
      phone: phone,
      area: areaId ?? 0,
    );
  }

  Future<String> resend(String email) => session.resend(email);

  Future<void> logout() async {
    await session.logout();
    favoriteIds = <int>{};
    notifyListeners();
  }

  Future<void> deleteAccount(String password) async {
    await session.deleteAccount(password);
    favoriteIds = <int>{};
    notifyListeners();
  }

  /// The server no longer accepts our token (changed password, removed device...).
  Future<void> handleAuthExpired() async {
    await session.expire();
    favoriteIds = <int>{};
    notifyListeners();
  }
}

/// Gives every screen access to [AppState] and rebuilds them when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this widget');
    return scope!.notifier!;
  }
}
