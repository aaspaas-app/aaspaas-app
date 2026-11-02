import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../app_state.dart';
import '../launch.dart';
import '../widgets/common.dart';
import '../widgets/listing_card.dart';
import '../widgets/news_panel.dart';
import 'area_picker.dart';
import 'filters_sheet.dart';
import 'listing_detail.dart';

/// The directory: news, search, filters and the list of businesses in the chosen area.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  int? _categoryId;
  int? _optionId;
  bool _openNow = false;
  bool _dealsOnly = false;
  bool _nearest = false;

  List<Listing> _items = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  ApiException? _error;
  bool _fromCache = false;
  DateTime? _cachedAt;
  int _gen = 0;
  String _sig = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 600)
        _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    // Reload only when the area or the GPS position changed, not for every small state change (hearts, news...).
    final sig =
        '${app.areaId}|${app.lat?.toStringAsFixed(2)}|${app.lng?.toStringAsFixed(2)}';
    if (sig != _sig) {
      _sig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ListingQuery _query(AppState app, int page) => ListingQuery(
    areaId: app.areaId,
    categoryId: _categoryId,
    optionId: _optionId,
    q: _search.text,
    openNow: _openNow,
    dealsOnly: _dealsOnly,
    nearest: _nearest && app.hasLocation,
    lat: app.lat,
    lng: app.lng,
    page: page,
  );

  Future<void> _load() async {
    final app = AppScope.of(context);
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final r = await app.repo.listings(_query(app, 1));
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = r.data.items;
        _page = r.data.page;
        _hasMore = r.data.hasMore;
        _fromCache = r.fromCache;
        _cachedAt = r.cachedAt;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _error != null) return;
    final app = AppScope.of(context);
    final gen = _gen;
    setState(() => _loadingMore = true);
    try {
      final r = await app.repo.listings(_query(app, _page + 1));
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = [..._items, ...r.data.items];
        _page = r.data.page;
        _hasMore = r.data.hasMore;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _loadingMore = false);
      toast(
        context,
        e.isNetwork ? 'No internet. Pull down to retry.' : e.message,
      );
    }
  }

  Future<void> _pickArea() async {
    final app = AppScope.of(context);
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute<int>(builder: (_) => const AreaPickerScreen()),
    );
    if (id != null) await app.setArea(id);
  }

  Future<void> _toggleNearest(bool on) async {
    final app = AppScope.of(context);
    if (on && !app.hasLocation) {
      final err = await app.useMyLocation();
      if (err != null) {
        if (mounted) toast(context, err);
        return;
      }
    }
    if (!mounted) return;
    setState(() => _nearest = on);
    _load();
  }

  Future<void> _openFilters() async {
    final cfg = AppScope.of(context).config;
    if (cfg == null) return;
    final r = await showFilterSheet(
      context,
      config: cfg,
      categoryId: _categoryId,
      optionId: _optionId,
    );
    if (r == null || !mounted) return;
    setState(() {
      _categoryId = r.categoryId;
      _optionId = r.optionId;
    });
    _load();
  }

  Widget _filterBar(AppState app) {
    final cfg = app.config;
    final cat = (cfg != null && _categoryId != null)
        ? cfg.categoryById(_categoryId!)
        : null;
    final hasFilters = _categoryId != null || _optionId != null;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          FilterChip(
            label: Text(
              cat?.name ?? (hasFilters ? 'Filters on' : 'Category & options'),
            ),
            avatar: const Icon(Icons.tune, size: 18),
            selected: hasFilters,
            onSelected: (_) => _openFilters(),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Open now'),
            selected: _openNow,
            onSelected: (v) {
              setState(() => _openNow = v);
              _load();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Deals today'),
            selected: _dealsOnly,
            onSelected: (v) {
              setState(() => _dealsOnly = v);
              _load();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Nearest'),
            avatar: const Icon(Icons.near_me, size: 18),
            selected: _nearest && app.hasLocation,
            onSelected: _toggleNearest,
          ),
        ],
      ),
    );
  }

  Widget _header(AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fromCache) OfflineBanner(cachedAt: _cachedAt),
        NewsPanel(areaId: app.areaId),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search shops, services, names',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                        _load();
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        _filterBar(app),
        const SizedBox(height: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: TextButton.icon(
          onPressed: _pickArea,
          icon: const Icon(Icons.place),
          label: Flexible(
            child: Text(
              app.areaLabel,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      body: _body(app),
    );
  }

  Widget _body(AppState app) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _header(app);
          if (i == _items.length + 1) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_items.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 40),
                child: MessageView(
                  icon: Icons.storefront_outlined,
                  title: 'No listings found',
                  message: app.areaId == null
                      ? 'Choose your area to see businesses near you.'
                      : 'Try another area or clear the filters.',
                  actionLabel: app.areaId == null ? 'Choose area' : null,
                  onAction: app.areaId == null ? _pickArea : null,
                ),
              );
            }
            return const SizedBox(height: 24);
          }
          final l = _items[i - 1];
          return ListingCard(
            listing: l,
            onOpen: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ListingDetailScreen(listingId: l.id, preview: l),
              ),
            ),
          );
        },
      ),
    );
  }
}
