// Network first, saved copy second: every read tries the server, and when there is no internet it falls back to the
// last good answer. A real server error (404, 401...) is never hidden by old data.
import 'api_client.dart';
import 'cache.dart';
import 'models.dart';

class Loaded<T> {
  const Loaded(this.data, {this.fromCache = false, this.cachedAt});
  final T data;
  final bool fromCache;
  final DateTime? cachedAt;
}

class ListingQuery {
  const ListingQuery({
    this.areaId,
    this.categoryId,
    this.optionId,
    this.q = '',
    this.openNow = false,
    this.dealsOnly = false,
    this.nearest = false,
    this.lat,
    this.lng,
    this.page = 1,
    this.perPage = 12,
  });

  final int? areaId;
  final int? categoryId;
  final int? optionId;
  final String q;
  final bool openNow;
  final bool dealsOnly;
  final bool nearest;
  final double? lat;
  final double? lng;
  final int page;
  final int perPage;

  bool get hasLocation => lat != null && lng != null;

  ListingQuery copyWith({int? page}) => ListingQuery(
    areaId: areaId,
    categoryId: categoryId,
    optionId: optionId,
    q: q,
    openNow: openNow,
    dealsOnly: dealsOnly,
    nearest: nearest,
    lat: lat,
    lng: lng,
    page: page ?? this.page,
    perPage: perPage,
  );

  Map<String, String> toParams() {
    final p = <String, String>{'page': '$page', 'per_page': '$perPage'};
    if (areaId != null && areaId! > 0) p['area'] = '$areaId';
    if (categoryId != null && categoryId! > 0) p['category'] = '$categoryId';
    if (optionId != null && optionId! > 0) p['option'] = '$optionId';
    if (q.trim().isNotEmpty) p['q'] = q.trim();
    if (openNow) p['open'] = '1';
    if (dealsOnly) p['deals'] = '1';
    if (hasLocation) {
      p['lat'] = lat!.toStringAsFixed(5);
      p['lng'] = lng!.toStringAsFixed(5);
      if (nearest) p['sort'] = 'distance';
    }
    return p;
  }

  /// Cache key. Location is rounded so a few metres of GPS drift does not create a new entry.
  String get cacheKey {
    final p = toParams();
    if (hasLocation) {
      p['lat'] = lat!.toStringAsFixed(2);
      p['lng'] = lng!.toStringAsFixed(2);
    }
    final keys = p.keys.toList()..sort();
    return 'listings:${keys.map((k) => '$k=${p[k]}').join('&')}';
  }
}

class Repository {
  Repository(this.api, this.cache);
  final ApiClient api;
  final JsonCache cache;

  Future<Loaded<T>> _load<T>(
    String key,
    Future<dynamic> Function() fetch,
    T Function(dynamic) parse,
  ) async {
    try {
      final raw = await fetch();
      await cache.put(key, raw);
      return Loaded<T>(parse(raw));
    } on ApiException catch (e) {
      if (!e.isNetwork) rethrow;
      final c = await cache.get(key);
      if (c == null) rethrow;
      return Loaded<T>(parse(c.data), fromCache: true, cachedAt: c.savedAt);
    }
  }

  Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  Future<Loaded<Config>> config() => _load(
    'config',
    () => api.get('/config'),
    (j) => Config.fromJson(_map(j)),
  );

  Future<Loaded<PagedResult<Listing>>> listings(ListingQuery q) => _load(
    q.cacheKey,
    () => api.get('/listings', query: q.toParams()),
    (j) => PagedResult.parse<Listing>(j, Listing.fromJson),
  );

  Future<Loaded<Listing>> listing(int id, {double? lat, double? lng}) {
    final query = <String, String>{};
    if (lat != null && lng != null) {
      query['lat'] = lat.toStringAsFixed(5);
      query['lng'] = lng.toStringAsFixed(5);
    }
    return _load(
      'listing:$id',
      () => api.get('/listings/$id', query: query),
      (j) => Listing.fromJson(_map(j)),
    );
  }

  Future<Loaded<PagedResult<Job>>> jobs({
    int? areaId,
    String q = '',
    int page = 1,
  }) {
    final p = <String, String>{'page': '$page'};
    if (areaId != null && areaId > 0) p['area'] = '$areaId';
    if (q.trim().isNotEmpty) p['q'] = q.trim();
    return _load(
      'jobs:${areaId ?? 0}:${q.trim()}:$page',
      () => api.get('/jobs', query: p),
      (j) => PagedResult.parse<Job>(j, Job.fromJson),
    );
  }

  Future<Loaded<Job>> job(int id) => _load(
    'job:$id',
    () => api.get('/jobs/$id'),
    (j) => Job.fromJson(_map(j)),
  );

  Future<Loaded<List<NewsItem>>> news({int? areaId}) {
    final p = <String, String>{};
    if (areaId != null && areaId > 0) p['area'] = '$areaId';
    return _load('news:${areaId ?? 0}', () => api.get('/news', query: p), (j) {
      final items = _map(j)['items'];
      return items is List
          ? items.map((e) => NewsItem.fromJson(_map(e))).toList()
          : <NewsItem>[];
    });
  }

  /// Signed-in only. The saved copy is kept so favorites are still there offline.
  Future<Loaded<List<Listing>>> favorites() =>
      _load('favorites', () => api.get('/me/favorites'), (j) {
        final items = _map(j)['items'];
        return items is List
            ? items.map((e) => Listing.fromJson(_map(e))).toList()
            : <Listing>[];
      });

  /// Returns true when the business is now saved.
  Future<bool> toggleFavorite(int id) async {
    final r = _map(await api.post('/listings/$id/favorite'));
    await cache.remove('favorites');
    await cache.remove('listing:$id');
    return r['saved'] == true;
  }

  /// Counts the tap on the server and returns the WhatsApp link to open.
  Future<String> tapDeal(int listingId, String dealId) async {
    final r = _map(
      await api.post(
        '/deals/tap',
        body: {'listing': listingId, 'deal': dealId},
      ),
    );
    return r['url']?.toString() ?? '';
  }

  /// Returns the message to show ("Thank you! ... will show after a quick check.").
  Future<String> submitReview(int listingId, int stars, String comment) async {
    final r = _map(
      await api.post(
        '/listings/$listingId/reviews',
        body: {'stars': stars, 'comment': comment},
      ),
    );
    await cache.remove('listing:$listingId');
    return r['message']?.toString() ?? '';
  }

  /// Forget everything that belongs to a signed-in person (called on logout and account deletion).
  Future<void> clearPersonalData() async {
    await cache.remove('favorites');
    await cache.remove('user');
    await cache.clearPrefix('listing:');
  }
}
