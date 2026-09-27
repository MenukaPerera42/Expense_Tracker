import 'package:expense_tracker/presentation/providers/theme_mode_provider.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

abstract class Initializer {
  Future<void> initialize();
}

class MockInitializer extends Mock implements Initializer {}

void main() {
  test('theme follows system then retains the session selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeModeProvider), ThemeMode.system);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.system);
    expect(container.read(themeModeProvider), ThemeMode.system);
  });

  test(
    'initialization caches success and retry executes after failure',
    () async {
      final initializer = MockInitializer();
      when(initializer.initialize)
          .thenAnswer((_) async => throw StateError('offline'));
      final container = ProviderContainer(
        overrides: [
          appInitializerProvider.overrideWithValue(initializer.initialize),
        ],
        retry: (retryCount, error) => null,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(appInitializationProvider.future),
        throwsStateError,
      );
      expect(container.read(appInitializationProvider).hasError, isTrue);
      when(initializer.initialize).thenAnswer((_) async {});
      container.invalidate(appInitializationProvider);
      await container.read(appInitializationProvider.future);
      await container.read(appInitializationProvider.future);
      verify(initializer.initialize).called(2);
    },
  );
}
