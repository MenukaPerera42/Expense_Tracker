import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_initialization.dart';
import '../domain/entities/expense.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/screens/add_expense_screen.dart';
import '../presentation/screens/auth_screen.dart';
import '../presentation/screens/edit_expense_screen.dart';
import '../presentation/screens/home_screen.dart';
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
      // Registration must finish saving the display name before leaving its form.
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
      GoRoute(
        path: AppRouter.homePath,
        name: AppRouter.homeName,
        builder: (_, _) => const _ProtectedHome(),
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
            EditExpenseScreen(expense: state.extra as Expense),
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

abstract final class AppRouter {
  static const homePath = '/';
  static const homeName = 'home';
  static const addExpensePath = '/expenses/add';
  static const addExpenseName = 'addExpense';
  static const editExpenseName = 'editExpense';

  /// Route pattern registered with go_router.
  static const editExpensePathPattern = '/expenses/:id/edit';

  /// Concrete path for a given expense ID. The full [Expense] is passed
  /// alongside as `extra` so the destination never has to re-fetch it.
  static String editExpensePath(String id) => '/expenses/$id/edit';
}

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

class _ProtectedHome extends ConsumerWidget {
  const _ProtectedHome();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading || auth.hasError || auth.value == null) {
      return const SplashScreen();
    }
    return const HomeScreen();
  }
}
