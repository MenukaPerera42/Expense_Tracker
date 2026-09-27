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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = const [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: items.map((item) {
            final isSelected = item.$1 == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () =>
                    ref.read(themeModeProvider.notifier).setMode(item.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0D47A1) // Dark Blue theme color
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0D47A1).withOpacity(0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.$2,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
