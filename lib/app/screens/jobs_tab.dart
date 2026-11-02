import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import '../widgets/common.dart';
import 'area_picker.dart';
import 'job_detail.dart';

/// Jobs posted by approved businesses, newest first.
class JobsTab extends StatefulWidget {
  const JobsTab({super.key});

  @override
  State<JobsTab> createState() => _JobsTabState();
}

class _JobsTabState extends State<JobsTab> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  bool _allAreas = false;
  List<Job> _items = const [];
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
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 500)
        _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sig = '${AppScope.of(context).areaId}';
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

  int? _area(AppState app) => _allAreas ? null : app.areaId;

  Future<void> _load() async {
    final app = AppScope.of(context);
    final gen = ++_gen;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final r = await app.repo.jobs(
        areaId: _area(app),
        q: _search.text,
        page: 1,
      );
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
      final r = await app.repo.jobs(
        areaId: _area(app),
        q: _search.text,
        page: _page + 1,
      );
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

  Widget _card(Job j) {
    final cs = Theme.of(context).colorScheme;
    final where = [
      if (j.business.isNotEmpty) j.business,
      if (j.area != null) j.area!.name,
    ].join(' · ');
    Widget fact(String icon, String text) => text.isEmpty
        ? const SizedBox.shrink()
        : Text('$icon $text', style: const TextStyle(fontSize: 13));
    return OutlinedCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => JobDetailScreen(jobId: j.id, preview: j),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            j.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          if (where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '🏢 $where',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              fact('🎓', j.qualification),
              fact('⏱', j.experience),
              fact('💰', j.salary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (j.applyBy.isNotEmpty)
                Text(
                  'Apply by ${shortDate(j.applyBy)}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              const Spacer(),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => JobDetailScreen(jobId: j.id, preview: j),
                  ),
                ),
                child: const Text('View details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Jobs')),
      body: Column(
        children: [
          if (_fromCache) OfflineBanner(cachedAt: _cachedAt),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search jobs',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.place, size: 18),
                  label: Text(_allAreas ? 'All areas' : app.areaLabel),
                  onPressed: _allAreas ? null : _pickArea,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All areas'),
                  selected: _allAreas,
                  onSelected: (v) {
                    setState(() => _allAreas = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty)
      return ErrorView(error: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 60),
            MessageView(
              icon: Icons.work_off_outlined,
              title: 'No jobs here yet',
              message: 'Check back soon, or look in all areas.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox(height: 24);
          }
          return _card(_items[i]);
        },
      ),
    );
  }
}
