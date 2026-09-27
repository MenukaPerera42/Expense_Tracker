import 'package:flutter/material.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:expense_tracker/data/services/local_preferences_providers.dart';
import 'package:expense_tracker/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/presentation/providers/currency_preference_provider.dart';
import 'package:expense_tracker/presentation/providers/theme_mode_provider.dart';
import 'package:expense_tracker/presentation/screens/settings_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository authRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepository = MockAuthRepository();
    when(authRepository.watchUser).thenAnswer(
      (_) => Stream.value(
        const AuthUser(id: 'user', name: 'Alex', email: 'alex@gmail.com'),
      ),
    );
    when(() => authRepository.logout()).thenAnswer((_) async {});
  });

  Future<ProviderContainer> mount(WidgetTester tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWith((ref) async => authRepository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('theme state and switching', () {
    testWidgets('appearance control reflects and updates the theme mode', (
      tester,
    ) async {
      final container = await mount(tester);
      expect(container.read(themeModeProvider), ThemeMode.system);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.light);

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(container.read(themeModeProvider), ThemeMode.system);
    });
  });

  group('theme persistence', () {
    testWidgets('switching the theme writes it to local storage', (
      tester,
    ) async {
      final container = await mount(tester);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      final prefs = await container.read(sharedPreferencesProvider.future);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    testWidgets('a previously persisted dark theme is restored on mount', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final container = await mount(tester);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('currency preference', () {
    testWidgets('picking a currency updates the shown code and persists it', (
      tester,
    ) async {
      final container = await mount(tester);
      expect(find.text('LKR'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'Currency'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(RadioListTile<CurrencyConfig>, 'USD'),
      );
      await tester.pumpAndSettle();

      expect(container.read(currencyPreferenceProvider).code, 'USD');
      final prefs = await container.read(sharedPreferencesProvider.future);
      expect(prefs.getString('currency_code'), 'USD');
    });
  });

  group('logout', () {
    testWidgets('confirming the dialog logs out through the repository', (
      tester,
    ) async {
      await mount(tester);
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Log out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pumpAndSettle();

      verify(() => authRepository.logout()).called(1);
    });

    testWidgets('cancelling the dialog does not log out', (tester) async {
      await mount(tester);
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Log out'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Log out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => authRepository.logout());
    });
  });

  group('app information', () {
    testWidgets('shows the app name and version', (tester) async {
      await mount(tester);
      await tester.scrollUntilVisible(
        find.text('Expense Tracker'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Expense Tracker'), findsOneWidget);
      expect(find.textContaining('Version'), findsOneWidget);
    });
  });
}
