import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../app_state.dart';

/// News and alerts the admin pushed from the backend. Alerts come first and are red. The x hides one on this phone.
class NewsPanel extends StatefulWidget {
  const NewsPanel({super.key, required this.areaId});
  final int? areaId;

  @override
  State<NewsPanel> createState() => _NewsPanelState();
}

class _NewsPanelState extends State<NewsPanel> {
  List<NewsItem> _items = const [];
  final Set<int> _open = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(NewsPanel old) {
    super.didUpdateWidget(old);
    if (old.areaId != widget.areaId) _load();
  }

  Future<void> _load() async {
    final repo = AppScope.of(context).repo;
    try {
      final r = await repo.news(areaId: widget.areaId);
      if (mounted) setState(() => _items = r.data);
    } on ApiException {
      // The panel is optional: no news is better than an error message.
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final visible = _items
        .where((n) => !app.seenNews.contains(n.seenKey))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          for (final n in visible)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: n.isAlert
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0F9FF),
                border: Border.all(
                  color: n.isAlert
                      ? const Color(0xFFFECACA)
                      : const Color(0xFFBAE6FD),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(
                  () => _open.contains(n.id)
                      ? _open.remove(n.id)
                      : _open.add(n.id),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.isAlert ? '🚨' : '📰',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            if (n.body.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  n.body,
                                  maxLines: _open.contains(n.id) ? null : 2,
                                  overflow: _open.contains(n.id)
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF374151),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF6B7280),
                        ),
                        onPressed: () => app.dismissNews(n),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
