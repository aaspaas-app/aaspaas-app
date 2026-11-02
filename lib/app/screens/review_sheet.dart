import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import 'auth_screen.dart';

/// Lets a signed-in person rate a business. Returns true when a review was sent.
Future<bool> showReviewSheet(BuildContext context, Listing listing) async {
  if (!await requireLogin(context)) return false;
  if (!context.mounted) return false;
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ReviewForm(listing: listing),
    ),
  );
  return sent == true;
}

class _ReviewForm extends StatefulWidget {
  const _ReviewForm({required this.listing});
  final Listing listing;

  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  late int _stars = widget.listing.myReview?.stars ?? 0;
  late final TextEditingController _comment = TextEditingController(
    text: widget.listing.myReview?.comment ?? '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_stars < 1) {
      setState(() => _error = 'Please tap a star rating from 1 to 5.');
      return;
    }
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await app.repo.submitReview(
        widget.listing.id,
        _stars,
        _comment.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      toast(
        context,
        msg.isEmpty
            ? 'Thank you! Your review will show after a quick check.'
            : msg,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isAuth) await app.handleAuthExpired();
      setState(() {
        _busy = false;
        _error = e.isNetwork
            ? 'You need internet to send a review.'
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.listing.myReview == null
                  ? 'Write a review'
                  : 'Your review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.listing.title,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    iconSize: 38,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _busy ? null : () => setState(() => _stars = i),
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _send,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send review'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews are checked before they appear.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
