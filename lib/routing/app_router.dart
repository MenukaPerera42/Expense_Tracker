import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_initialization.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/screens/add_expense_screen.dart';
import '../presentation/screens/analytics_screen.dart';
import '../presentation/screens/auth_screen.dart';
import '../presentation/screens/dashboard_view.dart';
import '../presentation/screens/edit_expense_screen.dart';
import '../presentation/screens/expense_history_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/widgets/status_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(appInitializationProvider, (_, _) => refresh.refresh());
  ref.listen(authStateProvider, (_, _) => refresh.refresh());
  ref.listen(authActionProvider, (_, _) => refresh.refresh());

  final router = GoRouter(
    initialLocation: AppRouter.homePath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final startup = ref.read(appInitializationProvider);
      final auth = ref.read(authStateProvider);
      final path = state.uri.path;
      if (startup.isLoading ||
          startup.hasError ||
          auth.isLoading ||
          auth.hasError) {
        return path == '/splash' ? null : '/splash';
      }
      final authPage = path == '/login' || path == '/register';
      if (auth.value == null) return authPage ? null : '/login';
      if (authPage && ref.read(authActionProvider).isLoading) return null;
      return authPage || path == '/splash' ? AppRouter.homePath : null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthScreen(key: ValueKey('login')),
      ),
      GoRoute(
        path: '/register',
        builder: (_, _) =>
            const AuthScreen(key: ValueKey('register'), register: true),
      ),

      // ── Shell: all authenticated screens share the persistent nav bar ──
      ShellRoute(
        builder: (context, state, child) {
          final auth = ref.read(authStateProvider);
          if (auth.isLoading || auth.hasError || auth.value == null) {
            return const SplashScreen();
          }
          return _AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: AppRouter.homePath,
            name: AppRouter.homeName,
            builder: (_, _) => const _DashboardPage(),
          ),
          GoRoute(
            path: AppRouter.analyticsPath,
            name: AppRouter.analyticsName,
            builder: (_, _) => const _AnalyticsPage(),
          ),
          GoRoute(
            path: AppRouter.addExpensePath,
            name: AppRouter.addExpenseName,
            builder: (_, _) => const AddExpenseScreen(),
          ),
          GoRoute(
            path: AppRouter.editExpensePathPattern,
            name: AppRouter.editExpenseName,
            builder: (_, state) =>
                EditExpenseScreen(expenseId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: AppRouter.expenseHistoryPath,
            name: AppRouter.expenseHistoryName,
            builder: (_, _) => const ExpenseHistoryScreen(),
          ),
          GoRoute(
            path: AppRouter.settingsPath,
            name: AppRouter.settingsName,
            builder: (_, _) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: SafeArea(
        child: StatusView(
          icon: Icons.wrong_location_outlined,
          title: 'Page not found',
          message: 'This page is not available.',
          action: FilledButton(
            onPressed: () => context.go(AppRouter.homePath),
            child: const Text('Go home'),
          ),
        ),
      ),
    ),
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

// ─── Shell scaffold ───────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: child,
      bottomNavigationBar: _PersistentNavBar(currentLocation: location),
    );
  }
}

// ─── Apple-style persistent nav bar ──────────────────────────────────────────

class _PersistentNavBar extends StatelessWidget {
  const _PersistentNavBar({required this.currentLocation});

  final String currentLocation;

  static const _leftTabs = [
    _TabData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
      path: AppRouter.homePath,
    ),
    _TabData(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Analytics',
      path: AppRouter.analyticsPath,
    ),
  ];

  static const _rightTabs = [
    _TabData(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'History',
      path: AppRouter.expenseHistoryPath,
    ),
    _TabData(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
      path: AppRouter.settingsPath,
    ),
  ];

  bool _isActive(_TabData tab) {
    if (tab.path == AppRouter.homePath) {
      return currentLocation == AppRouter.homePath;
    }
    if (tab.path == AppRouter.expenseHistoryPath) {
      return currentLocation == AppRouter.expenseHistoryPath; // Strict match
    }
    return currentLocation.startsWith(tab.path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF152236) : Colors.white;
    final shadowColor = isDark
        ? Colors.black.withOpacity(0.40)
        : Colors.black.withOpacity(0.09);

    return SafeArea(
      bottom: false, // Extend to the absolute bottom edge
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ── Full-width nav bar card ───────────────────────────────────────────
          Container(
            height:
                72 +
                MediaQuery.of(context)
                    .padding
                    .bottom, // Account for safe area internally
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(
                    0,
                    -4,
                  ), // Shadow goes UP since it's attached to bottom
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
              ],
            ),
            child: Row(
              children: [
                // Left two tabs
                ..._leftTabs.map(
                  (tab) => Expanded(
                    child: _NavTile(
                      tab: tab,
                      active: _isActive(tab),
                      isDark: isDark,
                      onTap: () => context.go(tab.path),
                    ),
                  ),
                ),
                // Gap for the raised center button
                const SizedBox(width: 68),
                // Right two tabs
                ..._rightTabs.map(
                  (tab) => Expanded(
                    child: _NavTile(
                      tab: tab,
                      active: _isActive(tab),
                      isDark: isDark,
                      onTap: () => context.go(tab.path),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Raised blue circle Add button ─────────────────────────────
          Positioned(
            top: -24,
            child: GestureDetector(
              onTap: () => context.go(AppRouter.addExpensePath),
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0D47A1),
                      Color(0xFF002171),
                    ], // Dark Blue, matching top card
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  // Shadow removed as requested
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab data ─────────────────────────────────────────────────────────────────

class _TabData {
  const _TabData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  // Retain the field so existing const instances remain hot-reload compatible.
  final bool isAction = false;
}

// ─── Nav tile ─────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.tab,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  final _TabData tab;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF1565C0);
    final inactiveColor = isDark
        ? const Color(0xFF607D8B)
        : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                active ? tab.activeIcon : tab.icon,
                key: ValueKey(active),
                color: active ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: active ? activeColor : inactiveColor,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page wrappers ────────────────────────────────────────────────────────────

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(bottom: false, child: DashboardView());
  }
}

class _AnalyticsPage extends StatelessWidget {
  const _AnalyticsPage();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(bottom: false, child: AnalyticsScreen());
  }
}

// ─── Router constants ─────────────────────────────────────────────────────────

abstract final class AppRouter {
  static const homePath = '/';
  static const homeName = 'home';
  static const analyticsPath = '/analytics';
  static const analyticsName = 'analytics';
  static const addExpensePath = '/expenses/add';
  static const addExpenseName = 'addExpense';
  static const editExpenseName = 'editExpense';
  static const expenseHistoryPath = '/expenses';
  static const expenseHistoryName = 'expenseHistory';
  static const settingsPath = '/settings';
  static const settingsName = 'settings';

  static const editExpensePathPattern = '/expenses/:id/edit';
  static String editExpensePath(String id) => '/expenses/$id/edit';
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}
