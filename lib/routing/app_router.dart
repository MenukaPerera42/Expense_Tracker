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
      // The child provides its own body (Scaffold or plain widget)
      body: child,
      bottomNavigationBar: _PersistentNavBar(currentLocation: location),
    );
  }
}

// ─── Persistent nav bar ───────────────────────────────────────────────────────

class _PersistentNavBar extends StatelessWidget {
  const _PersistentNavBar({required this.currentLocation});

  final String currentLocation;

  static const _tabs = [
    _TabData(
      icon: Icons.home_rounded,
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
    _TabData(
      icon: Icons.add_rounded,
      activeIcon: Icons.add_rounded,
      label: 'Add',
      path: AppRouter.addExpensePath,
      isAction: true,
    ),
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
    return currentLocation.startsWith(tab.path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const bg = Color(0xFF0A1628); // Deep navy

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _tabs.map((tab) {
              final active = _isActive(tab);
              return _NavButton(
                tab: tab,
                active: active,
                onTap: () => context.go(tab.path),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  const _TabData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
    this.isAction = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  final bool isAction;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _TabData tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Action (Add) button — pill-shaped accent button
    if (tab.isAction) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.55),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      );
    }

    // Regular tab button
    const activeColor = Color(0xFF90CAF9); // light-blue-200
    const inactiveColor = Color(0xFF546E7A); // blue-grey

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 64,
        height: 60,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0).withOpacity(0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing dot indicator above active icon
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 1.0 : 0.0,
              child: Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Icon(
              active ? tab.activeIcon : tab.icon,
              color: active ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                color: active ? activeColor : inactiveColor,
                fontSize: 9,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page wrappers (no Scaffold — shell provides it) ─────────────────────────

/// Dashboard page — wraps DashboardView with SafeArea for status bar.
class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(bottom: false, child: DashboardView());
  }
}

/// Analytics page wrapper.
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
