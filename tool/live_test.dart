// Runs the app's networking, offline cache and login logic against a real Aas Paas server.
// Usage: dart tool/live_test.dart http://127.0.0.1:8099/wp-json/aaspaas/v1 /tmp/seed.json
import 'dart:convert';
import 'dart:io';
import '../lib/core/api_client.dart';
import '../lib/core/cache.dart';
import '../lib/core/repository.dart';
import '../lib/core/session.dart';

int pass = 0, fail = 0;
void t(String name, bool ok, [Object? extra]) {
  if (ok) {
    pass++;
  } else {
    fail++;
    print('FAIL: $name ${extra ?? ''}');
  }
}

Future<ApiException?> expectApiError(Future<dynamic> Function() f) async {
  try {
    await f();
  } on ApiException catch (e) {
    return e;
  }
  return null;
}

Future<void> main(List<String> args) async {
  final base = args[0];
  final seed =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final ella = seed['ella'] as int,
      city = seed['city'] as int,
      other = seed['other'] as int;
  final l1 = seed['L1'] as int, jobId = seed['J'] as int;

  final api = ApiClient(baseUrl: base);
  final store = MemoryStore();
  final cache = JsonCache(store);
  final repo = Repository(api, cache);

  // ---------- config
  final cfg = (await repo.config()).data;
  t('config: api version', cfg.apiVersion == 1);
  t(
    'config: areas tree',
    cfg.areas.any((a) => a.name == 'Lahore' && a.children.length == 1),
  );
  t(
    'config: areaById city and locality',
    cfg.areaById(city)?.name == 'Lahore' &&
        cfg.areaById(ella)?.name == 'Ellahabad' &&
        cfg.areaById(9999) == null,
  );
  t('config: cityOf', cfg.cityOf(ella)?.id == city && cfg.cityOf(city) == null);
  t(
    'config: categories have food',
    cfg.categories.any((c) => c.slug == 'food'),
  );
  t('config: options', cfg.options.isNotEmpty);
  t(
    'config: category name is plain text',
    cfg.categories.any((c) => c.name == 'Shops & Markets'),
    cfg.categories.map((c) => c.name).toList(),
  );

  // ---------- listings
  var r = await repo.listings(ListingQuery(areaId: ella));
  t(
    'listings: page one has 12 of 16',
    r.data.items.length == 12 &&
        r.data.total == 16 &&
        r.data.totalPages == 2 &&
        r.data.hasMore &&
        !r.fromCache,
  );
  t(
    'listings: featured first',
    r.data.items.first.title == 'Taj Mahal Shadi Hall' &&
        r.data.items.first.featured,
  );
  final p2 = await repo.listings(ListingQuery(areaId: ella, page: 2));
  t(
    'listings: page two',
    p2.data.items.length == 4 && !p2.data.hasMore && p2.data.page == 2,
  );
  final ids = {
    ...r.data.items.map((e) => e.id),
    ...p2.data.items.map((e) => e.id),
  };
  t('listings: no duplicates across pages', ids.length == 16);
  r = await repo.listings(const ListingQuery(areaId: null, q: 'Bakery'));
  t(
    'listings: search',
    r.data.items.length == 1 && r.data.items.first.title == 'Kasur Bakery',
  );
  r = await repo.listings(ListingQuery(areaId: city, dealsOnly: true));
  final abc = r.data.items.isEmpty ? null : r.data.items.first;
  t(
    'listings: deals filter and parent area',
    r.data.items.length == 1 && abc!.title == 'ABC Grocery & Sons',
    r.data.items.map((e) => e.title).toList(),
  );
  t(
    'listing: plain text title with ampersand',
    abc != null && abc.title == 'ABC Grocery & Sons',
  );
  t(
    'listing: fields',
    abc != null &&
        abc.verified &&
        abc.category == 'Shops & Markets' &&
        abc.area?.name == 'Ellahabad' &&
        abc.phone == '03001112222' &&
        abc.whatsappUrl == 'https://wa.me/923001112222' &&
        abc.services.length == 5 &&
        abc.openNow == true &&
        abc.deals.length == 1,
  );
  t(
    'listing: deal',
    abc != null &&
        abc.deals.first.price == 999 &&
        abc.deals.first.old == 1200 &&
        abc.deals.first.hasOld &&
        abc.deals.first.id.isNotEmpty,
  );
  r = await repo.listings(
    ListingQuery(areaId: null, nearest: true, lat: 31.5204, lng: 74.3587),
  );
  t(
    'listings: nearest first with distance',
    r.data.items.first.distanceKm == 0.0 &&
        r.data.items.first.title == 'ABC Grocery & Sons',
    r.data.items.take(3).map((e) => '${e.title} ${e.distanceKm}').toList(),
  );
  r = await repo.listings(const ListingQuery(areaId: null, openNow: true));
  t(
    'listings: open now filter',
    r.data.items.isNotEmpty && r.data.items.every((e) => e.openNow == true),
  );
  t(
    'query: params',
    const ListingQuery(
          areaId: 5,
          categoryId: 2,
          q: ' a b ',
          openNow: true,
          dealsOnly: true,
        ).toParams().toString() ==
        '{page: 1, per_page: 12, area: 5, category: 2, q: a b, open: 1, deals: 1}',
  );
  t(
    'query: sort only with location',
    !const ListingQuery(nearest: true).toParams().containsKey('sort') &&
        const ListingQuery(nearest: true, lat: 1, lng: 2).toParams()['sort'] ==
            'distance',
  );
  t(
    'query: cache key rounds location',
    const ListingQuery(lat: 31.52041, lng: 74.35871).cacheKey ==
        const ListingQuery(lat: 31.52049, lng: 74.35869).cacheKey,
  );

  // ---------- details, jobs, news
  final d = (await repo.listing(l1)).data;
  t(
    'detail: fields',
    d.mapUrl.isNotEmpty &&
        d.reviews.isEmpty &&
        d.myReview == null &&
        d.jobs.length == 1 &&
        d.jobs.first.title == 'Sales Executive',
  );
  final nf = await expectApiError(() => repo.listing(999999));
  t(
    'detail: 404 is an error, not hidden',
    nf != null && nf.isNotFound && !nf.isNetwork,
  );
  final jobs = (await repo.jobs(areaId: ella)).data;
  t(
    'jobs: list',
    jobs.items.length == 1 &&
        jobs.items.first.title == 'Sales Executive' &&
        jobs.items.first.business == 'ABC Grocery & Sons' &&
        jobs.items.first.salary == 'Rs 30,000',
  );
  t(
    'jobs: other area empty',
    (await repo.jobs(areaId: other)).data.items.isEmpty,
  );
  final job = (await repo.job(jobId)).data;
  t(
    'job: details and apply link',
    job.details == 'Shop timings 9 to 9' &&
        job.whatsappUrl.startsWith('https://wa.me/923001112222?text=') &&
        job.phone == '03001112222',
  );
  final news = (await repo.news(areaId: ella)).data;
  t(
    'news: alert',
    news.length == 1 &&
        news.first.isAlert &&
        news.first.title == 'Heavy rain tonight' &&
        news.first.seenKey.startsWith('${news.first.id}-'),
  );

  // ---------- offline: same cache, unreachable server
  final dead = ApiClient(
    baseUrl: 'http://127.0.0.1:1/x',
    timeout: const Duration(seconds: 3),
  );
  final offline = Repository(dead, cache);
  final oc = await offline.config();
  t(
    'offline: config from cache',
    oc.fromCache &&
        oc.cachedAt != null &&
        oc.data.areas.length == cfg.areas.length,
  );
  final ol = await offline.listings(ListingQuery(areaId: ella));
  t(
    'offline: first page from cache',
    ol.fromCache &&
        ol.data.items.length == 12 &&
        ol.data.items.first.title == 'Taj Mahal Shadi Hall',
  );
  final od = await offline.listing(l1);
  t(
    'offline: details from cache',
    od.fromCache && od.data.title == 'ABC Grocery & Sons',
  );
  t(
    'offline: jobs and news from cache',
    (await offline.jobs(areaId: ella)).fromCache &&
        (await offline.news(areaId: ella)).fromCache,
  );
  final miss = await expectApiError(
    () =>
        offline.listings(const ListingQuery(areaId: null, q: 'never searched')),
  );
  t(
    'offline: query never seen gives a clear network error',
    miss != null && miss.isNetwork && miss.message.isNotEmpty,
    miss,
  );

  // ---------- non-JSON answers (host error page, blocked API)
  final html = ApiClient(baseUrl: base.replaceFirst('/wp-json/aaspaas/v1', ''));
  final bad = await expectApiError(() => html.get('/'));
  t(
    'bad response: HTML page is reported, not crashed',
    bad != null && bad.code == 'bad_response' && !bad.isNetwork,
    bad,
  );
  final nopath = await expectApiError(
    () => ApiClient(baseUrl: base).get('/does-not-exist'),
  );
  t(
    'unknown route is a 404 with WordPress message',
    nopath != null && nopath.status == 404,
    nopath,
  );

  // ---------- accounts
  final tokens = MemoryTokenStore();
  final session = Session(api, tokens, cache, repo, deviceName: 'Test phone');
  const email = 'Tester@Mail.pk';
  var e1 = await expectApiError(
    () => session.register(name: 'Test User', email: email, password: 'short'),
  );
  t(
    'register: short password message',
    e1 != null && e1.status == 400 && e1.code == 'short_pass',
    e1,
  );
  final msg = await session.register(
    name: 'Test User',
    email: email,
    password: 'secret1234',
    phone: '0300 1234567',
    area: ella,
  );
  t('register: friendly message', msg.toLowerCase().contains('email'), msg);
  e1 = await expectApiError(
    () => session.register(name: 'Again', email: email, password: 'secret1234'),
  );
  t(
    'register: duplicate email 409',
    e1 != null && e1.status == 409 && e1.code == 'email_exists',
    e1,
  );
  e1 = await expectApiError(() => session.login(email, 'secret1234'));
  t(
    'login: blocked until the email is confirmed',
    e1 != null &&
        e1.code == 'unverified' &&
        e1.status == 401 &&
        !session.loggedIn,
    e1,
  );
  t('resend: answers', (await session.resend(email)).isNotEmpty);
  final v = await Process.run('php', [
    '/home/claude/wp/verify_user.php',
    email.toLowerCase(),
  ]);
  t('verify helper', v.stdout.toString().contains('verified'), v.stdout);
  e1 = await expectApiError(() => session.login(email, 'wrong-pass'));
  t('login: wrong password', e1 != null && e1.code == 'invalid', e1);
  final u = await session.login(email, 'secret1234');
  t(
    'login: user',
    session.loggedIn &&
        u.email == 'tester@mail.pk' &&
        u.type == 'customer' &&
        u.area == ella &&
        api.token != null &&
        tokens.value == api.token,
  );

  // restore on a fresh app start
  final api2 = ApiClient(baseUrl: base);
  final repo2 = Repository(api2, cache);
  final s2 = Session(api2, tokens, cache, repo2);
  await s2.restore();
  t(
    'restore: signed in again from the stored token',
    s2.loggedIn && s2.user!.name == 'Test User',
  );
  // restore with no internet keeps the person signed in
  final apiDead = ApiClient(
    baseUrl: 'http://127.0.0.1:1/x',
    timeout: const Duration(seconds: 3),
  );
  final s3 = Session(apiDead, tokens, cache, Repository(apiDead, cache));
  await s3.restore();
  t(
    'restore offline: stays signed in from the saved profile',
    s3.loggedIn &&
        s3.user!.email == 'tester@mail.pk' &&
        apiDead.token == tokens.value,
  );
  // a token the server rejects is dropped
  final badTokens = MemoryTokenStore()..value = '1.${'a' * 40}';
  final api4 = ApiClient(baseUrl: base);
  final s4 = Session(
    api4,
    badTokens,
    JsonCache(MemoryStore()),
    Repository(api4, JsonCache(MemoryStore())),
  );
  await s4.restore();
  t(
    'restore: invalid token is cleared',
    !s4.loggedIn && badTokens.value == null && api4.token == null,
  );

  // favorites and reviews
  t('favorites: none yet', (await repo.favorites()).data.isEmpty);
  t('favorites: toggle on', await repo.toggleFavorite(l1) == true);
  final favs = (await repo.favorites()).data;
  t(
    'favorites: listed with heart',
    favs.length == 1 && favs.first.id == l1 && favs.first.isFavorite,
  );
  final dd = (await repo.listing(l1)).data;
  t('detail: heart is on for the signed-in user', dd.isFavorite);
  final rm = await repo.submitReview(l1, 4, 'Fresh & clean <b>shop</b>');
  t('review: message', rm.toLowerCase().contains('review'), rm);
  final d2 = (await repo.listing(l1)).data;
  t(
    'review: my review shows as pending, not public',
    d2.myReview != null &&
        d2.myReview!.isPending &&
        d2.myReview!.stars == 4 &&
        d2.reviews.isEmpty &&
        !d2.myReview!.comment.contains('<b>'),
    d2.myReview?.comment,
  );
  final rbad = await expectApiError(() => repo.submitReview(l1, 9, ''));
  t(
    'review: bad stars rejected with a message',
    rbad != null && rbad.status == 400 && rbad.message.isNotEmpty,
    rbad,
  );
  final tap = await repo.tapDeal(l1, abc!.deals.first.id);
  t(
    'deal tap: returns the WhatsApp link with the deal text',
    tap.startsWith('https://wa.me/923001112222?text=') &&
        Uri.decodeComponent(tap).contains('Sugar 5Kg Bag'),
    tap,
  );
  final tapBad = await expectApiError(() => repo.tapDeal(l1, 'nope'));
  t(
    'deal tap: unknown deal is a 404',
    tapBad != null && tapBad.status == 404,
    tapBad,
  );

  // logout clears everything personal
  await session.logout();
  t(
    'logout: local state cleared',
    !session.loggedIn && api.token == null && tokens.value == null,
  );
  t(
    'logout: cached favorites and detail removed',
    await cache.get('favorites') == null &&
        await cache.get('user') == null &&
        await cache.get('listing:$l1') == null,
  );
  final unauth = await expectApiError(() => repo.favorites());
  t(
    'after logout: favorites need sign-in (401)',
    unauth != null && unauth.isAuth,
    unauth,
  );

  // delete account
  await session.login(email, 'secret1234');
  final wrong = await expectApiError(() => session.deleteAccount('nope'));
  t(
    'delete: wrong password refused and still signed in',
    wrong != null && wrong.status == 403 && session.loggedIn,
    wrong,
  );
  await session.deleteAccount('secret1234');
  t('delete: signed out', !session.loggedIn && tokens.value == null);
  e1 = await expectApiError(() => session.login(email, 'secret1234'));
  t('delete: account really gone', e1 != null && e1.code == 'invalid', e1);

  // cache eviction
  final small = JsonCache(MemoryStore(), maxEntries: 3);
  await small.put('config', {'a': 1});
  for (var i = 0; i < 6; i++) {
    await small.put('k$i', {'i': i});
  }
  t(
    'cache: oldest evicted, protected kept',
    await small.get('config') != null &&
        await small.get('k0') == null &&
        await small.get('k5') != null &&
        await small.get('k3') == null,
  );
  await small.clearPrefix('k');
  t(
    'cache: clearPrefix',
    await small.get('k5') == null && await small.get('config') != null,
  );
  final corrupt = MemoryStore()..data['c:x'] = '{not json';
  t(
    'cache: corrupt entry reads as missing',
    await JsonCache(corrupt).get('x') == null,
  );

  api.close();
  print('\n$pass passed, $fail failed');
  exit(fail == 0 ? 0 : 1);
}
