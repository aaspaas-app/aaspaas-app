// Tiny offline cache: remembers the last good answer for each screen so the app still works without internet.
import 'dart:convert';

/// Where cached text lives. The app uses shared_preferences; tests use [MemoryStore].
abstract class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class MemoryStore implements KeyValueStore {
  final Map<String, String> data = {};
  @override
  Future<String?> getString(String key) async => data[key];
  @override
  Future<void> setString(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

class CachedJson {
  const CachedJson(this.data, this.savedAt);
  final dynamic data;
  final DateTime savedAt;
}

class JsonCache {
  JsonCache(
    this.store, {
    this.maxEntries = 60,
    this.protectedKeys = const {'config', 'favorites', 'user'},
  });

  final KeyValueStore store;
  final int maxEntries;

  /// These are never evicted to make room.
  final Set<String> protectedKeys;

  static const _indexKey = 'cache_index';

  Future<List<String>> _index() async {
    final s = await store.getString(_indexKey);
    if (s == null) return <String>[];
    try {
      return (jsonDecode(s) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> put(String key, dynamic data) async {
    await store.setString(
      'c:$key',
      jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'd': data}),
    );
    final idx = await _index();
    idx.remove(key);
    idx.add(key); // most recent last
    while (idx.length > maxEntries) {
      final victim = idx.firstWhere(
        (k) => !protectedKeys.contains(k),
        orElse: () => '',
      );
      if (victim.isEmpty) break;
      idx.remove(victim);
      await store.remove('c:$victim');
    }
    await store.setString(_indexKey, jsonEncode(idx));
  }

  Future<CachedJson?> get(String key) async {
    final s = await store.getString('c:$key');
    if (s == null) return null;
    try {
      final m = jsonDecode(s) as Map;
      return CachedJson(
        m['d'],
        DateTime.fromMillisecondsSinceEpoch((m['t'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    await store.remove('c:$key');
    final idx = await _index();
    if (idx.remove(key)) await store.setString(_indexKey, jsonEncode(idx));
  }

  Future<void> clearPrefix(String prefix) async {
    final idx = await _index();
    final gone = idx.where((k) => k.startsWith(prefix)).toList();
    for (final k in gone) {
      await store.remove('c:$k');
      idx.remove(k);
    }
    await store.setString(_indexKey, jsonEncode(idx));
  }
}
