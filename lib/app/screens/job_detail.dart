import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../launch.dart';
import '../theme.dart';
import '../widgets/common.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId, this.preview});
  final int jobId;
  final Job? preview;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Job? _job;
  bool _fromCache = false;
  DateTime? _cachedAt;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _job = widget.preview;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repo = AppScope.of(context).repo;
    try {
      final r = await repo.job(widget.jobId);
      if (!mounted) return;
      setState(() {
        _job = r.data;
        _fromCache = r.fromCache;
        _cachedAt = r.cachedAt;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Widget _fact(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, style: const TextStyle(fontSize: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = _job;
    if (j == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? ErrorView(error: _error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final where = [
      if (j.business.isNotEmpty) j.business,
      if (j.area != null) j.area!.name,
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_fromCache) OfflineBanner(cachedAt: _cachedAt),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              j.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(where, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          if (!j.open)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'This job is closed. The last date to apply has passed.',
                style: TextStyle(color: Color(0xFF92400E)),
              ),
            ),
          const SizedBox(height: 8),
          _fact(Icons.school_outlined, 'Qualification', j.qualification),
          _fact(Icons.timelapse, 'Experience', j.experience),
          _fact(Icons.payments_outlined, 'Salary', j.salary),
          _fact(
            Icons.event,
            'Apply by',
            j.applyBy.isEmpty ? '' : shortDate(j.applyBy),
          ),
          if (j.details.isNotEmpty) ...[
            const SectionTitle('Details'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                j.details,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
            ),
          ],
          if (j.open && (j.phone.isNotEmpty || j.whatsappUrl.isNotEmpty)) ...[
            const SectionTitle('How to apply'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (j.phone.isNotEmpty)
                    CircleAction(
                      icon: Icons.call,
                      label: 'Call',
                      color: brand,
                      size: 52,
                      onTap: () => callNumber(context, j.phone),
                    ),
                  if (j.phone.isNotEmpty && j.whatsappUrl.isNotEmpty)
                    const SizedBox(width: 14),
                  if (j.whatsappUrl.isNotEmpty)
                    CircleAction(
                      icon: Icons.chat_rounded,
                      label: 'WhatsApp',
                      color: whatsappGreen,
                      size: 52,
                      onTap: () => openOrWarn(context, j.whatsappUrl),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
