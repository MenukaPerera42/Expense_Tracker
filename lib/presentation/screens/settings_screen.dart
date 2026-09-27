import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_constants.dart';
import '../providers/auth_providers.dart';
import '../providers/currency_preference_provider.dart';
import '../providers/theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            const _SectionHeader('Appearance'),
            const _AppearanceTile(),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const _SectionHeader('Currency'),
            const _CurrencyTile(),
            const Divider(height: 1),
            const _SectionHeader('Account'),
            const _LogoutTile(),
            const Divider(height: 1),
            const _SectionHeader('About'),
            const _AppInfoTile(),
          ],
        ),
      ),
      floatingActionButton: action.isLoading
          ? const FloatingActionButton.small(
              onPressed: null,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Text(
        label,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_outlined),
            label: Text('System'),
          ),
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Dark'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) =>
            ref.read(themeModeProvider.notifier).setMode(selection.first),
      ),
    );
  }
}

class _CurrencyTile extends ConsumerWidget {
  const _CurrencyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyPreferenceProvider);
    return ListTile(
      leading: const Icon(Icons.attach_money_outlined),
      title: const Text('Currency'),
      subtitle: Text(currency.code),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _pickCurrency(context, ref),
    );
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currencyPreferenceProvider);
    final selected = await showModalBottomSheet<CurrencyConfig>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: RadioGroup<CurrencyConfig>(
            groupValue: current,
            onChanged: (value) => Navigator.of(sheetContext).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose currency'),
                  ),
                ),
                for (final option in CurrencyConfig.options)
                  RadioListTile<CurrencyConfig>(
                    value: option,
                    title: Text(option.code),
                    subtitle: Text(option.locale),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      await ref.read(currencyPreferenceProvider.notifier).setCurrency(selected);
    }
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authActionProvider);
    return ListTile(
      leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
      title: Text(
        'Log out',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
      onTap: action.isLoading ? null : () => _confirmLogout(context, ref),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authActionProvider.notifier).logout();
    }
  }
}

class _AppInfoTile extends StatelessWidget {
  const _AppInfoTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.info_outline),
      title: Text(AppConstants.appName),
      subtitle: Text('Version ${AppConstants.appVersion}'),
    );
  }
}
