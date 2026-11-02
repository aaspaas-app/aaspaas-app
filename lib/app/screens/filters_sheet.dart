import 'package:flutter/material.dart';

import '../../core/models.dart';

class FilterChoice {
  const FilterChoice({this.categoryId, this.optionId});
  final int? categoryId;
  final int? optionId;
}

/// Bottom sheet to pick a category and an option (for example "Delivery available"). Returns the new choice.
Future<FilterChoice?> showFilterSheet(
  BuildContext context, {
  required Config config,
  int? categoryId,
  int? optionId,
}) {
  return showModalBottomSheet<FilterChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _FilterSheet(
      config: config,
      categoryId: categoryId,
      optionId: optionId,
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.config, this.categoryId, this.optionId});
  final Config config;
  final int? categoryId;
  final int? optionId;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  int? _cat;
  int? _opt;

  @override
  void initState() {
    super.initState();
    _cat = widget.categoryId;
    _opt = widget.optionId;
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                Text(
                  'Category',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _chip(
                      'All',
                      _cat == null,
                      () => setState(() => _cat = null),
                    ),
                    for (final c in cfg.categories)
                      _chip(
                        c.name,
                        _cat == c.id,
                        () => setState(() => _cat = c.id),
                      ),
                  ],
                ),
                for (final c in cfg.categories)
                  if (c.children.isNotEmpty &&
                      (_cat == c.id ||
                          c.children.any((k) => k.id == _cat))) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${c.name} types',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final k in c.children)
                          _chip(
                            k.name,
                            _cat == k.id,
                            () => setState(() => _cat = k.id),
                          ),
                      ],
                    ),
                  ],
                if (cfg.options.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _chip(
                        'Any',
                        _opt == null,
                        () => setState(() => _opt = null),
                      ),
                      for (final o in cfg.options)
                        _chip(
                          o.name,
                          _opt == o.id,
                          () => setState(() => _opt = o.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const FilterChoice()),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(FilterChoice(categoryId: _cat, optionId: _opt)),
                    child: const Text('Show results'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
