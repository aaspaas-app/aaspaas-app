import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';

/// Round icon button used for Call and WhatsApp (icons only, with a label for screen readers and long-press).
class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 44,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: Colors.white, size: size * 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small rounded label.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.background,
    this.foreground,
    this.outlined = false,
    this.bold = false,
  });
  final String text;
  final Color? background;
  final Color? foreground;
  final bool outlined;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? null : (background ?? cs.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(20),
        border: outlined ? Border.all(color: cs.outlineVariant) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: foreground ?? cs.onSurface,
        ),
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});
  @override
  Widget build(BuildContext context) => const Pill(
    '✔ Verified',
    background: Color(0xFFDBEAFE),
    foreground: Color(0xFF1E40AF),
    bold: true,
  );
}

/// Open now / Closed / On holiday.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.openNow, required this.onHoliday});
  final bool? openNow;
  final bool onHoliday;

  @override
  Widget build(BuildContext context) {
    if (onHoliday)
      return const Pill(
        'On holiday',
        background: Color(0xFFFEF3C7),
        foreground: Color(0xFF92400E),
        bold: true,
      );
    if (openNow == true)
      return const Pill(
        'Open now',
        background: Color(0xFFDCFCE7),
        foreground: Color(0xFF166534),
        bold: true,
      );
    if (openNow == false)
      return const Pill(
        'Closed',
        background: Color(0xFFFEE2E2),
        foreground: Color(0xFF991B1B),
        bold: true,
      );
    return const SizedBox.shrink();
  }
}

class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.stars, this.size = 16});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: const Color(0xFFF59E0B),
          ),
      ],
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.cachedAt});
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final when = cachedAt == null ? '' : ' (saved ${savedAgo(cachedAt!)})';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFF92400E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No internet. Showing saved results$when.',
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.outline),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error with a Try again button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      icon: error.isNetwork ? Icons.wifi_off : Icons.error_outline,
      title: error.isNetwork ? 'You are offline' : 'Something went wrong',
      message: error.message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// A bordered white card, like the cards on the website.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.fromLTRB(12, 6, 12, 6),
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
