import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bussin/features/map/map_screen.dart';
import 'package:bussin/features/favorites/favorites_screen.dart';
import 'package:bussin/features/settings/settings_screen.dart';

/// ---------------------------------------------------------------------------
/// Bottom Navigation Bar
/// ---------------------------------------------------------------------------
/// Three-tab bottom navigation using Material 3 NavigationBar and IndexedStack.
///
/// Tabs:
///   0 - Map      (Icons.map)       -> MapScreen
///   1 - Favorites (Icons.star)      -> FavoritesScreen
///   2 - Settings  (Icons.settings)  -> SettingsScreen
///
/// Each tab maintains its own navigation stack so the user can push
/// screens within a tab without losing state in other tabs.
///
/// The Map tab's nav bar includes action buttons for history (clock)
/// and alerts (bell with badge), handled within MapScreen itself.
/// ---------------------------------------------------------------------------

/// Main scaffold widget that wraps the app's bottom tab navigation.
///
/// Uses Material 3 NavigationBar with three tabs, each containing its
/// own IndexedStack for independent navigation stacks.
class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MapScreen(),
          FavoritesScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
