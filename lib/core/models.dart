// Plain data classes for the Aas Paas API. No Flutter imports, so they can be tested with plain Dart.
// Parsing is forgiving: a missing or oddly typed field never crashes the app.

String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
String? _sn(dynamic v) =>
    (v == null || v.toString().isEmpty) ? null : v.toString();

int _i(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

double? _dn(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _b(dynamic v) => v == true || v == 1 || v == '1';
bool? _bn(dynamic v) => v == null ? null : _b(v);
List<dynamic> _l(dynamic v) => v is List ? v : const <dynamic>[];
Map<String, dynamic> _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<String> _strings(dynamic v) => _l(v).map((e) => e.toString()).toList();

/// A node of the areas, categories or options lists.
class Term {
  const Term({
    required this.id,
    required this.name,
    required this.slug,
    this.children = const [],
  });
  final int id;
  final String name;
  final String slug;
  final List<Term> children;

  factory Term.fromJson(Map<String, dynamic> j) => Term(
    id: _i(j['id']),
    name: _s(j['name']),
    slug: _s(j['slug']),
    children: _l(j['children']).map((e) => Term.fromJson(_m(e))).toList(),
  );
}

class Config {
  const Config({
    required this.apiVersion,
    required this.site,
    required this.areas,
    required this.categories,
    required this.options,
    required this.maxDeals,
  });
  final int apiVersion;
  final String site;
  final List<Term> areas;
  final List<Term> categories;
  final List<Term> options;
  final int maxDeals;

  factory Config.fromJson(Map<String, dynamic> j) => Config(
    apiVersion: _i(j['api_version'], 1),
    site: _s(j['site']),
    areas: _l(j['areas']).map((e) => Term.fromJson(_m(e))).toList(),
    categories: _l(j['categories']).map((e) => Term.fromJson(_m(e))).toList(),
    options: _l(j['options']).map((e) => Term.fromJson(_m(e))).toList(),
    maxDeals: _i(j['max_deals'], 5),
  );

  /// Finds an area (city or locality) by id.
  Term? areaById(int id) {
    for (final city in areas) {
      if (city.id == id) return city;
      for (final loc in city.children) {
        if (loc.id == id) return loc;
      }
    }
    return null;
  }

  /// The city a locality belongs to, or null when [id] is a city (or unknown).
  Term? cityOf(int id) {
    for (final city in areas) {
      for (final loc in city.children) {
        if (loc.id == id) return city;
      }
    }
    return null;
  }

  Term? categoryById(int id) {
    for (final c in categories) {
      if (c.id == id) return c;
      for (final k in c.children) {
        if (k.id == id) return k;
      }
    }
    return null;
  }
}

class AreaRef {
  const AreaRef({required this.id, required this.name});
  final int id;
  final String name;
  factory AreaRef.fromJson(Map<String, dynamic> j) =>
      AreaRef(id: _i(j['id']), name: _s(j['name']));
}

class Rating {
  const Rating({required this.avg, required this.count});
  final double avg;
  final int count;
}

class Deal {
  const Deal({
    required this.id,
    required this.title,
    required this.price,
    required this.old,
    required this.until,
  });
  final String id;
  final String title;
  final int price;
  final int old;
  final String until; // YYYY-MM-DD
  bool get hasOld => old > 0 && old > price;

  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
    id: _s(j['id']),
    title: _s(j['title']),
    price: _i(j['price']),
    old: _i(j['old']),
    until: _s(j['until']),
  );
}

class Extra {
  const Extra({
    required this.label,
    required this.number,
    required this.call,
    required this.wa,
  });
  final String label;
  final String number;
  final bool call;
  final bool wa;
  factory Extra.fromJson(Map<String, dynamic> j) => Extra(
    label: _s(j['label']),
    number: _s(j['number']),
    call: _b(j['call']),
    wa: _b(j['wa']),
  );
}

class Review {
  const Review({
    required this.id,
    required this.name,
    required this.stars,
    required this.comment,
    required this.date,
  });
  final int id;
  final String name;
  final int stars;
  final String comment;
  final String date;
  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: _i(j['id']),
    name: _s(j['name']),
    stars: _i(j['stars'], 1).clamp(1, 5),
    comment: _s(j['comment']),
    date: _s(j['date']),
  );
}

class MyReview {
  const MyReview({
    required this.stars,
    required this.comment,
    required this.status,
  });
  final int stars;
  final String comment;
  final String status; // publish or pending
  bool get isPending => status != 'publish';
  factory MyReview.fromJson(Map<String, dynamic> j) => MyReview(
    stars: _i(j['stars'], 1).clamp(1, 5),
    comment: _s(j['comment']),
    status: _s(j['status']),
  );
}

class JobRef {
  const JobRef({required this.id, required this.title});
  final int id;
  final String title;
  factory JobRef.fromJson(Map<String, dynamic> j) =>
      JobRef(id: _i(j['id']), title: _s(j['title']));
}

/// One business. List items fill the first group of fields; the details screen also fills the second group.
class Listing {
  const Listing({
    required this.id,
    required this.title,
    this.category = '',
    this.icon = '',
    this.area,
    this.place = '',
    this.photo,
    this.rating,
    this.verified = false,
    this.featured = false,
    this.openNow,
    this.timings = '',
    this.onHoliday = false,
    this.backOn = '',
    this.options = const [],
    this.services = const [],
    this.phone = '',
    this.whatsapp = '',
    this.whatsappUrl = '',
    this.lat,
    this.lng,
    this.distanceKm,
    this.deals = const [],
    this.isFavorite = false,
    this.mapUrl = '',
    this.photoLarge,
    this.extras = const [],
    this.reviews = const [],
    this.myReview,
    this.jobs = const [],
  });

  final int id;
  final String title;
  final String category;
  final String icon;
  final AreaRef? area;
  final String place;
  final String? photo;
  final Rating? rating;
  final bool verified;
  final bool featured;
  final bool? openNow; // null when the business gave no timings
  final String timings;
  final bool onHoliday;
  final String backOn;
  final List<String> options;
  final List<String> services;
  final String phone;
  final String whatsapp;
  final String whatsappUrl;
  final double? lat;
  final double? lng;
  final double? distanceKm;
  final List<Deal> deals;
  final bool isFavorite;

  // Details screen only.
  final String mapUrl;
  final String? photoLarge;
  final List<Extra> extras;
  final List<Review> reviews;
  final MyReview? myReview;
  final List<JobRef> jobs;

  bool get hasPhone => phone.isNotEmpty;
  bool get hasWhatsapp => whatsapp.isNotEmpty;

  factory Listing.fromJson(Map<String, dynamic> j) {
    final r = j['rating'];
    return Listing(
      id: _i(j['id']),
      title: _s(j['title']),
      category: _s(j['category']),
      icon: _s(j['icon']),
      area: j['area'] is Map ? AreaRef.fromJson(_m(j['area'])) : null,
      place: _s(j['place']),
      photo: _sn(j['photo']),
      rating: r is Map
          ? Rating(avg: _dn(r['avg']) ?? 0, count: _i(r['count']))
          : null,
      verified: _b(j['verified']),
      featured: _b(j['featured']),
      openNow: _bn(j['open_now']),
      timings: _s(j['timings']),
      onHoliday: _b(j['on_holiday']),
      backOn: _s(j['back_on']),
      options: _strings(j['options']),
      services: _strings(j['services']),
      phone: _s(j['phone']),
      whatsapp: _s(j['whatsapp']),
      whatsappUrl: _s(j['whatsapp_url']),
      lat: _dn(j['lat']),
      lng: _dn(j['lng']),
      distanceKm: _dn(j['distance_km']),
      deals: _l(j['deals']).map((e) => Deal.fromJson(_m(e))).toList(),
      isFavorite: _b(j['is_favorite']),
      mapUrl: _s(j['map_url']),
      photoLarge: _sn(j['photo_large']),
      extras: _l(j['extras']).map((e) => Extra.fromJson(_m(e))).toList(),
      reviews: _l(j['reviews']).map((e) => Review.fromJson(_m(e))).toList(),
      myReview: j['my_review'] is Map
          ? MyReview.fromJson(_m(j['my_review']))
          : null,
      jobs: _l(j['jobs']).map((e) => JobRef.fromJson(_m(e))).toList(),
    );
  }
}

class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.total,
    required this.totalPages,
  });
  final List<T> items;
  final int page;
  final int total;
  final int totalPages;
  bool get hasMore => page < totalPages;

  static PagedResult<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) item,
  ) {
    final j = _m(json);
    return PagedResult<T>(
      items: _l(j['items']).map((e) => item(_m(e))).toList(),
      page: _i(j['page'], 1),
      total: _i(j['total']),
      totalPages: _i(j['total_pages'], 1),
    );
  }
}

class Job {
  const Job({
    required this.id,
    required this.title,
    this.businessId,
    this.business = '',
    this.area,
    this.experience = '',
    this.qualification = '',
    this.salary = '',
    this.applyBy = '',
    this.posted = '',
    this.open = true,
    this.details = '',
    this.phone = '',
    this.whatsapp = '',
    this.whatsappUrl = '',
  });
  final int id;
  final String title;
  final int? businessId;
  final String business;
  final AreaRef? area;
  final String experience;
  final String qualification;
  final String salary;
  final String applyBy;
  final String posted;
  final bool open;
  final String details;
  final String phone;
  final String whatsapp;
  final String whatsappUrl;

  factory Job.fromJson(Map<String, dynamic> j) {
    final biz = j['business'];
    return Job(
      id: _i(j['id']),
      title: _s(j['title']),
      businessId: biz is Map ? _i(biz['id']) : null,
      business: biz is Map ? _s(biz['title']) : '',
      area: j['area'] is Map ? AreaRef.fromJson(_m(j['area'])) : null,
      experience: _s(j['experience']),
      qualification: _s(j['qualification']),
      salary: _s(j['salary']),
      applyBy: _s(j['apply_by']),
      posted: _s(j['posted']),
      open: j['open'] == null ? true : _b(j['open']),
      details: _s(j['details']),
      phone: _s(j['phone']),
      whatsapp: _s(j['whatsapp']),
      whatsappUrl: _s(j['whatsapp_url']),
    );
  }
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.date,
    required this.updated,
  });
  final int id;
  final String type; // news or alert
  final String title;
  final String body;
  final String date;
  final int updated;
  bool get isAlert => type == 'alert';

  /// Changes when the admin edits the item, so a dismissed item can come back once.
  String get seenKey => '$id-$updated';

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
    id: _i(j['id']),
    type: _s(j['type'], 'news'),
    title: _s(j['title']),
    body: _s(j['body']),
    date: _s(j['date']),
    updated: _i(j['updated']),
  );
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    required this.area,
  });
  final int id;
  final String name;
  final String email;
  final String type; // customer, business or admin
  final int area;
  bool get isBusiness => type == 'business' || type == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: _i(j['id']),
    name: _s(j['name']),
    email: _s(j['email']),
    type: _s(j['type'], 'customer'),
    area: _i(j['area']),
  );
}
