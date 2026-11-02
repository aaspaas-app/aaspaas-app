import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/deal_banner.dart';
import '../widgets/listing_card.dart';
import 'job_detail.dart';
import 'review_sheet.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId, this.preview});
  final int listingId;

  /// The card the person tapped, shown straight away while the details load.
  final Listing? preview;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _l;
  bool _detailLoaded = false;
  bool _fromCache = false;
  DateTime? _cachedAt;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _l = widget.preview;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    try {
      final r = await app.repo.listing(
        widget.listingId,
        lat: app.lat,
        lng: app.lng,
      );
      if (!mounted) return;
      setState(() {
        _l = r.data;
        _detailLoaded = true;
        _fromCache = r.fromCache;
        _cachedAt = r.cachedAt;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _review() async {
    final l = _l;
    if (l == null) return;
    final sent = await showReviewSheet(context, l);
    if (sent && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.title, overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: HeartButton(listingId: l.id, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (!_detailLoaded && _error == null)
            const LinearProgressIndicator(minHeight: 2),
          if (_fromCache) OfflineBanner(cachedAt: _cachedAt),
          if (_error != null && !_detailLoaded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                _error!.isNetwork
                    ? 'No internet. Some details could not load.'
                    : _error!.message,
                style: TextStyle(color: cs.error),
              ),
            ),
          _header(l, cs),
          _actions(l),
          if (l.onHoliday) _holidayNote(l),
          if (l.deals.isNotEmpty) ...[
            const SectionTitle('Deals'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (final d in l.deals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: DealTile(listing: l, deal: d),
                    ),
                ],
              ),
            ),
          ],
          _info(l, cs),
          if (l.extras.isNotEmpty) _extras(l),
          if (l.jobs.isNotEmpty) _jobs(l),
          _reviews(l, cs),
        ],
      ),
    );
  }

  Widget _header(Listing l, ColorScheme cs) {
    return OutlinedCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListingThumb(listing: l, size: 84),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                RatingLine(listing: l),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (l.verified) const VerifiedBadge(),
                    StatusPill(openNow: l.openNow, onHoliday: l.onHoliday),
                    if (l.distanceKm != null) Pill(distanceText(l.distanceKm!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelled(Widget button, String label) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Column(
      children: [
        button,
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );

  Widget _actions(Listing l) {
    final items = <Widget>[];
    if (l.hasPhone) {
      items.add(
        _labelled(
          CircleAction(
            icon: Icons.call,
            label: 'Call',
            color: brand,
            size: 56,
            onTap: () => callNumber(context, l.phone),
          ),
          'Call',
        ),
      );
    }
    if (l.hasWhatsapp) {
      items.add(
        _labelled(
          CircleAction(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: whatsappGreen,
            size: 56,
            onTap: () => openOrWarn(context, l.whatsappUrl),
          ),
          'WhatsApp',
        ),
      );
    }
    final map = l.mapUrl;
    if (map.isNotEmpty) {
      items.add(
        _labelled(
          CircleAction(
            icon: Icons.directions,
            label: 'Directions',
            color: const Color(0xFF2563EB),
            size: 56,
            onTap: () => openOrWarn(context, map),
          ),
          'Directions',
        ),
      );
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: items),
    );
  }

  Widget _holidayNote(Listing l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        l.backOn.isEmpty
            ? 'This business is on holiday right now.'
            : 'This business is on holiday. Back on ${shortDate(l.backOn)}.',
        style: const TextStyle(color: Color(0xFF92400E)),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Widget _info(Listing l, ColorScheme cs) {
    final place = [
      if (l.place.isNotEmpty) l.place,
      if (l.area != null && !l.place.contains(l.area!.name)) l.area!.name,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('About'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.isNotEmpty) _row(Icons.place, place),
              if (l.timings.isNotEmpty) _row(Icons.schedule, l.timings),
              if (l.category.isNotEmpty)
                _row(Icons.category_outlined, l.category),
              if (l.options.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final o in l.options) Pill(o, bold: true)],
                ),
              ],
              if (l.services.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Services', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in l.services) Pill(s, outlined: true),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _extras(Listing l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('More numbers'),
        for (final e in l.extras)
          ListTile(
            dense: true,
            title: Text(e.label.isEmpty ? e.number : e.label),
            subtitle: e.label.isEmpty ? null : Text(e.number),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.call)
                  CircleAction(
                    icon: Icons.call,
                    label: 'Call ${e.label}',
                    color: brand,
                    size: 38,
                    onTap: () => callNumber(context, e.number),
                  ),
                if (e.call && e.wa) const SizedBox(width: 8),
                if (e.wa)
                  CircleAction(
                    icon: Icons.chat_rounded,
                    label: 'WhatsApp ${e.label}',
                    color: whatsappGreen,
                    size: 38,
                    onTap: () => openOrWarn(
                      context,
                      'https://wa.me/${_waDigits(e.number)}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// 03001234567 -> 923001234567 (Pakistan). Numbers already in international form are kept.
  String _waDigits(String n) {
    var d = n.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = '92${d.substring(1)}';
    return d;
  }

  Widget _jobs(Listing l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Jobs here'),
        for (final j in l.jobs)
          ListTile(
            leading: const Icon(Icons.work_outline),
            title: Text(j.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => JobDetailScreen(jobId: j.id),
              ),
            ),
          ),
      ],
    );
  }

  Widget _reviews(Listing l, ColorScheme cs) {
    final r = l.rating;
    final mine = l.myReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Reviews'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (r != null) ...[
                Text(
                  '★ ${r.avg.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${r.count} review${r.count == 1 ? '' : 's'}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ] else
                Text(
                  'No reviews yet',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _review,
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: Text(mine == null ? 'Write a review' : 'Edit my review'),
              ),
            ],
          ),
        ),
        if (mine != null && mine.isPending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Your review is waiting for approval.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
        for (final rv in l.reviews)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StarsRow(stars: rv.stars),
                    const SizedBox(width: 8),
                    Text(
                      rv.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rv.date,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (rv.comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(rv.comment),
                  ),
                const Divider(height: 20),
              ],
            ),
          ),
      ],
    );
  }
}
