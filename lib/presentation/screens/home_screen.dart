import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../providers/auth_providers.dart';
import '../../routing/app_router.dart';
import 'dashboard_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionProvider);
    ref.listen(authActionProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(next.error))));
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: action.isLoading
                ? null
                : () => ref.read(authActionProvider.notifier).logout(),
            icon: action.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRouter.settingsPath),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: const SafeArea(child: DashboardView()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRouter.addExpensePath),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
    );
  }
}
