import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/presentation/providers/currency_preference_provider.dart';
import 'package:expense_tracker/presentation/providers/theme_mode_provider.dart';
import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:expense_tracker/data/services/local_preferences_providers.dart';

void main() {
  group('ThemeModeController', () {
    test('defaults to system before persisted state loads', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });

    test('restores a previously persisted theme mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(themeModeProvider);
      await container.read(sharedPreferencesProvider.future);
      // Allow the controller's async restore to complete.
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setMode updates state immediately and persists it', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.light);

      expect(container.read(themeModeProvider), ThemeMode.light);
      final prefs = await container.read(sharedPreferencesProvider.future);
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('theme switching moves between all three modes', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(themeModeProvider.notifier);

      await notifier.setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await notifier.setMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      await notifier.setMode(ThemeMode.system);
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('CurrencyPreferenceController', () {
    test('defaults to the default currency before persisted state loads', () {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(currencyPreferenceProvider),
        CurrencyConfig.defaultCurrency,
      );
    });

    test('restores a previously persisted currency', () async {
      SharedPreferences.setMockInitialValues({'currency_code': 'USD'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(currencyPreferenceProvider);
      await container.read(sharedPreferencesProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currencyPreferenceProvider).code, 'USD');
    });

    test('setCurrency updates state and persists the chosen code', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const eur = CurrencyConfig(code: 'EUR', locale: 'en_IE');
      await container
          .read(currencyPreferenceProvider.notifier)
          .setCurrency(eur);

      expect(container.read(currencyPreferenceProvider), eur);
      final prefs = await container.read(sharedPreferencesProvider.future);
      expect(prefs.getString('currency_code'), 'EUR');
    });
  });
}
