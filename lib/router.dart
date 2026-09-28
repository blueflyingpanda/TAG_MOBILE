import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'features/game/game_play_screen.dart';
import 'features/game/game_setup_screen.dart';
import 'features/game/round_results_screen.dart';
import 'features/history/game_history_screen.dart';
import 'features/login_screen.dart';
import 'features/rules_screen.dart';
import 'features/themes/create_theme_screen.dart';
import 'features/themes/edit_theme_screen.dart';
import 'features/themes/theme_details_screen.dart';
import 'features/themes/theme_selection_screen.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

String _gameLocation(GameState game) => game.hasPendingResults ? '/results' : '/play';

Page<void> _page(GoRouterState state, Widget child) =>
    MaterialPage(key: state.pageKey, child: AppBackground(child: child));

/// Round results slide up from the bottom (web: y 100vh → 0 spring).
Page<void> _sheetPage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      child: AppBackground(child: child),
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final user = ref.read(authProvider);
  final game = ref.read(gameProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    refreshListenable: refresh,
    initialLocation: user == null ? '/login' : (game != null ? _gameLocation(game) : '/'),
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final loc = state.matchedLocation;
      if (!loggedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login') {
        final g = ref.read(gameProvider);
        return g != null ? _gameLocation(g) : '/';
      }
      if ((loc == '/play' || loc == '/results') && ref.read(gameProvider) == null) return '/';
      if (loc == '/setup' && state.extra is! GameTheme) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (_, s) => _page(s, const LoginScreen())),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, shell) => _page(state, _HomeShell(shell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const ThemeSelectionScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/history', builder: (_, _) => const GameHistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/rules', builder: (_, _) => const RulesScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/theme/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _page(s, ThemeDetailsScreen(themeId: int.parse(s.pathParameters['id']!))),
        routes: [
          GoRoute(
            path: 'edit',
            parentNavigatorKey: _rootKey,
            pageBuilder: (_, s) => _page(s, EditThemeScreen(themeId: int.parse(s.pathParameters['id']!))),
          ),
        ],
      ),
      GoRoute(path: '/create', parentNavigatorKey: _rootKey, pageBuilder: (_, s) => _page(s, const CreateThemeScreen())),
      GoRoute(
        path: '/setup',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _page(s, GameSetupScreen(theme: s.extra! as GameTheme)),
      ),
      GoRoute(
        path: '/history/:id',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _page(s, GameDetailsScreen(gameId: int.parse(s.pathParameters['id']!))),
      ),
      GoRoute(path: '/play', parentNavigatorKey: _rootKey, pageBuilder: (_, s) => _page(s, const GamePlayScreen())),
      GoRoute(
        path: '/results',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, s) => _sheetPage(s, const RoundResultsScreen()),
      ),
    ],
  );
});

class _HomeShell extends ConsumerWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          shell.goBranch(i, initialLocation: i == shell.currentIndex);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.style_outlined),
            selectedIcon: const Icon(Icons.style_rounded),
            label: t.nav_home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_toggle_off_rounded),
            label: t.nav_history,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: t.nav_rules,
          ),
        ],
      ),
    );
  }
}
