import 'dart:async';

import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/presentation/providers/theme_mode_provider.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Trivial stand-in so Home's expense history stream has something to watch
/// without contacting Firebase; this file is not about expense behavior.
class _EmptyExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getExpenses({bool descending = true}) async => [];
  @override
  Future<Expense?> getExpenseById(String id) async => null;
  @override
  Stream<List<Expense>> watchExpenses({bool descending = true}) =>
      Stream.value(const []);
  @override
  String newExpenseId() => 'unused';
  @override
  Future<void> createExpense(Expense expense) async {}
  @override
  Future<void> updateExpense(Expense expense) async {}
  @override
  Future<void> deleteExpense(String id) async {}
}

void main() {
  Future<ProviderContainer> mount(
    WidgetTester tester, {
    Future<void> Function()? initialize,
  }) async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        appInitializerProvider.overrideWithValue(initialize ?? () async {}),
        authStateProvider.overrideWith((ref) async* {
          await ref.watch(appInitializationProvider.future);
          yield const AuthUser(id: 'test');
        }),
        expenseRepositoryProvider.overrideWith(
          (ref) async => _EmptyExpenseRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExpenseTrackerApp(),
      ),
    );
    return container;
  }

  testWidgets('startup shows progress then opens the workspace', (
    tester,
  ) async {
    final ready = Completer<void>();
    await mount(tester, initialize: () => ready.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Expense Tracker'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Expense Tracker'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('startup failure is recoverable with an explicit retry', (
    tester,
  ) async {
    var attempts = 0;
    await mount(
      tester,
      initialize: () async {
        if (++attempts == 1) throw StateError('unavailable');
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Unable to start'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Expense Tracker'), findsOneWidget);
  });

  testWidgets('appearance menu switches the rendered theme', (tester) async {
    final container = await mount(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark theme'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('unknown route offers working recovery', (tester) async {
    final container = await mount(tester);
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/missing');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.text('Expense Tracker'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(1024, 768)]) {
    testWidgets('shell handles $size and large text without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('No expenses in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
