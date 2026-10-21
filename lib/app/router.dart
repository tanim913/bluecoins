import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/add/add_sheet.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/more/backup_screen.dart';
import '../features/more/bills_screen.dart';
import '../features/more/import_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/settings_screen.dart';
import '../features/more/what_if_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const home = '/';
  static const history = '/history';
  static const insights = '/insights';
  static const more = '/more';
  static const whatIf = '/more/what-if';
  static const bills = '/more/bills';
  static const settings = '/more/settings';
  static const backup = '/more/backup';
  static const importText = '/more/import';
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(snapshotProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    navigatorKey: _rootKey,
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(snapshotProvider).value;
      if (s == null) return null; // still loading: never redirect on a guess
      final inWelcome = state.matchedLocation == Routes.welcome;
      if (!s.onboarded && !inWelcome) return Routes.welcome;
      if (s.onboarded && inWelcome) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.history,
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.insights,
                builder: (_, _) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'what-if',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const WhatIfScreen(),
                  ),
                  GoRoute(
                    path: 'bills',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const BillsScreen(),
                  ),
                  GoRoute(
                    path: 'backup',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const BackupScreen(),
                  ),
                  GoRoute(
                    path: 'import',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const ImportScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Persist cycle starts the rule generated, so changing the rule later never moves past cycles.
    ref.listenManual(overviewProvider, fireImmediately: true, (_, o) {
      if (o == null) return;
      final store = ref.read(storeProvider);
      for (final d in o.missingStarts) {
        store.addCycleStart(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.shell.currentIndex;
    return Scaffold(
      body: widget.shell,
      floatingActionButton: i != 1
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (n) =>
            widget.shell.goBranch(n, initialLocation: n == i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
