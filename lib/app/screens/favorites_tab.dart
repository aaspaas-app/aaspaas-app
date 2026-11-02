import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../widgets/common.dart';
import '../widgets/listing_card.dart';
import 'auth_screen.dart';
import 'listing_detail.dart';

/// Businesses the person saved with the heart. Works offline from the last saved copy.
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  List<Listing> _items = const [];
  bool _loading = false;
  ApiException? _error;
  bool _fromCache = false;
  DateTime? _cachedAt;
  String _sig = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    // Reload when the person signs in or out, or when a heart is toggled anywhere in the app.
    final sig =
        '${app.loggedIn}|${(app.favoriteIds.toList()..sort()).join(',')}';
    if (sig != _sig) {
      _sig = sig;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    if (!app.loggedIn) {
      setState(() {
        _items = const [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await app.repo.favorites();
      if (!mounted) return;
      setState(() {
        _items = r.data;
        _fromCache = r.fromCache;
        _cachedAt = r.cachedAt;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isAuth) await app.handleAuthExpired();
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget body;
    if (!app.loggedIn) {
      body = MessageView(
        icon: Icons.favorite_border,
        title: 'Save your favorite places',
        message:
            'Log in to keep a list of the businesses you like, even without internet.',
        actionLabel: 'Log in',
        onAction: () => requireLogin(context),
      );
    } else if (_loading && _items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _items.isEmpty) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = const MessageView(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        message: 'Tap the heart on a business to save it here.',
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_fromCache) OfflineBanner(cachedAt: _cachedAt),
            for (final l in _items)
              ListingCard(
                listing: l,
                onOpen: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ListingDetailScreen(listingId: l.id, preview: l),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: body,
    );
  }
}
