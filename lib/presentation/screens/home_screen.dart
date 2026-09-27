import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../providers/theme_mode_provider.dart';
import '../providers/auth_providers.dart';
import '../widgets/status_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final action = ref.watch(authActionProvider);
    ref.listen(authActionProvider, (previous, next) {
      if (next.hasError)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authErrorMessage(next.error))));
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
          PopupMenuButton<ThemeMode>(
            tooltip: 'Appearance',
            icon: const Icon(Icons.brightness_6_outlined),
            initialValue: mode,
            onSelected: ref.read(themeModeProvider.notifier).setMode,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ThemeMode.system,
                child: Text('System theme'),
              ),
              PopupMenuItem(value: ThemeMode.light, child: Text('Light theme')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Dark theme')),
            ],
          ),
        ],
      ),
      body: const SafeArea(
        child: StatusView(
          icon: Icons.account_balance_wallet_outlined,
          title: 'A clearer view of your spending',
          message:
              'Your expense workspace is taking shape. '
              'Expense tracking is coming next.',
        ),
      ),
    );
  }
}
