import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import '../theme.dart';

/// Taps a deal: the server counts it (admin statistics) and returns the WhatsApp link with the message written.
Future<void> claimDeal(BuildContext context, Listing listing, Deal deal) async {
  final app = AppScope.of(context);
  try {
    final url = await app.repo.tapDeal(listing.id, deal.id);
    if (!context.mounted) return;
    if (url.isNotEmpty) await openOrWarn(context, url);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (e.isNetwork && listing.whatsappUrl.isNotEmpty) {
      // No internet for the counter: still let the person reach the business.
      await openOrWarn(
        context,
        '${listing.whatsappUrl}?text=${Uri.encodeComponent(dealMessage(deal.title, deal.price))}',
      );
    } else {
      toast(context, e.message);
    }
  }
}

class DealTile extends StatelessWidget {
  const DealTile({super.key, required this.listing, required this.deal});
  final Listing listing;
  final Deal deal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4EC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFFB923C)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => claimDeal(context, listing, deal),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: _DealTag(),
                            ),
                          ),
                          TextSpan(
                            text: deal.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          rs(deal.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: dealOrange,
                            fontSize: 16,
                          ),
                        ),
                        if (deal.hasOld)
                          Text(
                            rs(deal.old),
                            style: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          'Until ${shortDate(deal.until)}',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_rounded, color: Color(0xFF15803D), size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Tap to claim',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealTag extends StatelessWidget {
  const _DealTag();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: dealOrange,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      '🔥 Deal',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

/// One deal, or a swipeable set of deals with dots underneath.
class DealBanner extends StatefulWidget {
  const DealBanner({super.key, required this.listing});
  final Listing listing;

  @override
  State<DealBanner> createState() => _DealBannerState();
}

class _DealBannerState extends State<DealBanner> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final deals = widget.listing.deals;
    if (deals.isEmpty) return const SizedBox.shrink();
    if (deals.length == 1)
      return DealTile(listing: widget.listing, deal: deals.first);
    return Column(
      children: [
        SizedBox(
          height: 86,
          child: PageView.builder(
            itemCount: deals.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DealTile(listing: widget.listing, deal: deals[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < deals.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? dealOrange : const Color(0xFFD1D5DB),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
