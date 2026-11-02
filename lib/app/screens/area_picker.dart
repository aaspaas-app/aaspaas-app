import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/common.dart';

/// Pick a city or a locality. Pops with the chosen area id.
class AreaPickerScreen extends StatefulWidget {
  const AreaPickerScreen({super.key});

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(int id) => Navigator.of(context).pop(id);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cfg = app.config;
    final current = app.areaId;

    Widget body;
    if (cfg == null) {
      body = MessageView(
        icon: Icons.wifi_off,
        title: 'Could not load areas',
        message: app.configError ?? 'Please check your internet connection.',
        actionLabel: 'Try again',
        onAction: app.loadConfig,
      );
    } else if (cfg.areas.isEmpty) {
      body = const MessageView(
        icon: Icons.location_off,
        title: 'No areas yet',
        message: 'The directory has not added any areas.',
      );
    } else if (_q.trim().isNotEmpty) {
      final q = _q.trim().toLowerCase();
      final rows = <Widget>[];
      for (final city in cfg.areas) {
        if (city.name.toLowerCase().contains(q)) {
          rows.add(_tile(city.name, city.id, current));
        }
        for (final loc in city.children) {
          if (loc.name.toLowerCase().contains(q) ||
              city.name.toLowerCase().contains(q)) {
            rows.add(_tile('${loc.name}, ${city.name}', loc.id, current));
          }
        }
      }
      body = rows.isEmpty
          ? const MessageView(icon: Icons.search_off, title: 'No matching area')
          : ListView(children: rows);
    } else {
      body = ListView(
        children: [
          for (final city in cfg.areas)
            if (city.children.isEmpty)
              _tile(city.name, city.id, current)
            else
              ExpansionTile(
                initiallyExpanded:
                    current == city.id ||
                    city.children.any((c) => c.id == current),
                title: Text(
                  city.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: [
                  _tile('All of ${city.name}', city.id, current),
                  for (final loc in city.children)
                    _tile(loc.name, loc.id, current),
                ],
              ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose your area')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: 'Search city or locality',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() => _q = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _tile(String title, int id, int? current) {
    return ListTile(
      leading: const Icon(Icons.place_outlined),
      title: Text(title),
      trailing: id == current
          ? const Icon(Icons.check_circle, color: Color(0xFF0F766E))
          : null,
      onTap: () => _choose(id),
    );
  }
}
