import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/l10n.dart';
import '../../core/widgets/menu_button.dart';
import '../../core/widgets/offline_banner.dart';
import '../kirtan/presentation/widgets/mini_player.dart';
import 'app_drawer.dart';

/// Root layout: five bottom tabs, the app drawer, the offline banner and the
/// persistent kirtan mini player.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTabSelected(int index) {
    HapticFeedback.selectionClick();
    // Tapping the active tab again returns to the root of that tab.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Android back closes an open drawer first. This runs before go_router
  /// handles back, which would otherwise pop the page under the drawer (on a
  /// page inside a tab) or switch to Home with the drawer still open.
  static Future<bool> _closeDrawerOnBack() async => _closeDrawer();

  static bool _closeDrawer() {
    final ScaffoldState? scaffold = shellScaffoldKey.currentState;
    if (scaffold == null || !scaffold.isDrawerOpen) return false;
    // Leave back to a full-screen page opened above the shell.
    if (!(ModalRoute.isCurrentOf(scaffold.context) ?? true)) return false;
    scaffold.closeDrawer();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return BackButtonListener(
      onBackButtonPressed: _closeDrawerOnBack,
      child: PopScope(
        // Android back on a non-home tab goes to Home instead of closing the
        // app.
        canPop: navigationShell.currentIndex == 0,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (didPop || _closeDrawer()) return;
          navigationShell.goBranch(0);
        },
        child: _buildScaffold(l10n),
      ),
    );
  }

  Widget _buildScaffold(AppLocalizations l10n) {
    return Scaffold(
      key: shellScaffoldKey,
      drawer: const AppDrawer(),
      body: Column(
        children: <Widget>[
          Expanded(child: navigationShell),
          const OfflineBanner(),
          const MiniPlayer(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.music_note_outlined),
            selectedIcon: const Icon(Icons.music_note_rounded),
            label: l10n.navKirtan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.place_outlined),
            selectedIcon: const Icon(Icons.place_rounded),
            label: l10n.navPlaces,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: l10n.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.celebration_outlined),
            selectedIcon: const Icon(Icons.celebration_rounded),
            label: l10n.navEvents,
          ),
        ],
      ),
    );
  }
}
