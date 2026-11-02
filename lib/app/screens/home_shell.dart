import 'package:flutter/material.dart';

import '../app_state.dart';
import 'account_tab.dart';
import 'area_picker.dart';
import 'favorites_tab.dart';
import 'home_tab.dart';
import 'jobs_tab.dart';

/// Bottom navigation with the four main tabs. Each tab keeps its place while you switch.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // First launch: ask for the area straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = AppScope.of(context);
      if (app.areaId == null && app.config != null) {
        final id = await Navigator.of(context).push<int>(
          MaterialPageRoute<int>(
            builder: (_) => const AreaPickerScreen(),
            fullscreenDialog: true,
          ),
        );
        if (id != null) await app.setArea(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeTab(), JobsTab(), FavoritesTab(), AccountTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
