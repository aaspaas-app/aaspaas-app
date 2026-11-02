import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import '../screens/auth_screen.dart';
import '../theme.dart';
import 'common.dart';
import 'deal_banner.dart';

/// The picture (or category icon) of a business.
class ListingThumb extends StatelessWidget {
  const ListingThumb({super.key, required this.listing, this.size = 92});
  final Listing listing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(
        listing.icon.isEmpty ? '🏪' : listing.icon,
        style: TextStyle(fontSize: size * 0.42),
      ),
    );
    final photo = listing.photo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? fallback
          : Image.network(
              photo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}

/// The heart. Asks the person to log in first when needed.
class HeartButton extends StatelessWidget {
  const HeartButton({super.key, required this.listingId, this.size = 18});
  final int listingId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final on = app.isFavorite(listingId);
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: on ? 'Remove from favorites' : 'Save to favorites',
      child: Material(
        color: cs.surface,
        elevation: 1,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            if (!app.loggedIn) {
              final ok = await requireLogin(context);
              if (!ok || !context.mounted) return;
            }
            final err = await app.toggleFavorite(listingId);
            if (err != null && context.mounted) toast(context, err);
          },
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              on ? Icons.favorite : Icons.favorite_border,
              size: size,
              color: const Color(0xFFE11D48),
            ),
          ),
        ),
      ),
    );
  }
}

/// Call and WhatsApp as round icon buttons.
class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, required this.listing, this.size = 44});
  final Listing listing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (l.hasPhone)
          CircleAction(
            icon: Icons.call,
            label: 'Call',
            color: brand,
            size: size,
            onTap: () => callNumber(context, l.phone),
          ),
        if (l.hasPhone && l.hasWhatsapp) const SizedBox(width: 10),
        if (l.hasWhatsapp)
          CircleAction(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: whatsappGreen,
            size: size,
            onTap: () => openOrWarn(context, l.whatsappUrl),
          ),
      ],
    );
  }
}

class RatingLine extends StatelessWidget {
  const RatingLine({super.key, required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = listing.rating;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        if (r != null) ...[
          Text(
            '★ ${r.avg.toStringAsFixed(1)}',
            style: const TextStyle(
              color: Color(0xFFD97706),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '(${r.count})',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ] else
          Text(
            '☆ No reviews',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        if (listing.category.isNotEmpty) ...[
          Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
          Text(
            listing.category,
            style: const TextStyle(
              color: brand,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onOpen});
  final Listing listing;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = listing;
    final place = [
      if (l.place.isNotEmpty) l.place,
      if (l.area != null && !l.place.contains(l.area!.name)) l.area!.name,
    ].join(' · ');
    final shown = l.services.take(3).toList();
    final more = l.services.length - shown.length;

    return OutlinedCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ListingThumb(listing: l),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: HeartButton(listingId: l.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StatusPill(openNow: l.openNow, onHoliday: l.onHoliday),
                    if (l.timings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l.timings,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (l.options.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final o in l.options.take(2))
                              Pill(o, bold: true),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            l.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (l.verified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    RatingLine(listing: l),
                    if (place.isNotEmpty || l.distanceKm != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.place,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                [
                                  if (place.isNotEmpty) place,
                                  if (l.distanceKm != null)
                                    distanceText(l.distanceKm!),
                                ].join(' · '),
                                style: const TextStyle(
                                  color: brand,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (shown.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final s in shown) Pill(s, outlined: true),
                            if (more > 0) Pill('+$more more', outlined: true),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    ContactButtons(listing: l),
                  ],
                ),
              ),
            ],
          ),
          if (l.deals.isNotEmpty) ...[
            const SizedBox(height: 10),
            DealBanner(listing: l),
          ],
        ],
      ),
    );
  }
}
