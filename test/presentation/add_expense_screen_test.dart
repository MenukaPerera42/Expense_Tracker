import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

Expense _fallbackExpense() => Expense(
  id: 'fallback',
  userId: 'user-1',
  title: 'Fallback',
  amount: 1,
  category: ExpenseCategory.other,
  date: DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late MockExpenseRepository repository;

  setUpAll(() {
    registerFallbackValue(_fallbackExpense());
  });

  setUp(() {
    repository = MockExpenseRepository();
    when(() => repository.newExpenseId()).thenReturn('new-expense-id');
    // Home's expense history view watches this as soon as the app becomes
    // authenticated; stub it so returning to Home after a save doesn't hit
    // an unstubbed call.
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value(const []));
  });

  Future<ProviderContainer> mount(WidgetTester tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appInitializerProvider.overrideWithValue(() async {}),
        authStateProvider.overrideWith((ref) async* {
          yield const AuthUser(id: 'user-1');
        }),
        expenseRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openAddExpense(WidgetTester tester) async {
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save expense'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save expense'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty title shows a validation message and blocks submission', (
    tester,
  ) async {
    await mount(tester);
    await openAddExpense(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10');
    await tester.tap(find.text('Food'));
    await tapSave(tester);
    expect(find.text('Enter a title.'), findsOneWidget);
    verifyNever(() => repository.createExpense(any()));
  });

  testWidgets('malformed and zero amounts are both rejected', (tester) async {
    await mount(tester);
    await openAddExpense(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Lunch');
    await tester.tap(find.text('Food'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '1.2.3',
    );
    await tapSave(tester);
    expect(find.text('Enter a valid number.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '0');
    await tapSave(tester);
    expect(find.text('Amount must be greater than zero.'), findsOneWidget);
    verifyNever(() => repository.createExpense(any()));
  });

  testWidgets('missing category blocks submission with an inline message', (
    tester,
  ) async {
    await mount(tester);
    await openAddExpense(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Lunch');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10');
    await tapSave(tester);
    expect(find.text('Choose a category.'), findsOneWidget);
    verifyNever(() => repository.createExpense(any()));
  });

  testWidgets(
    'valid submission shows a saving state, then success and returns home',
    (tester) async {
      final done = Completer<void>();
      when(
        () => repository.createExpense(any()),
      ).thenAnswer((_) => done.future);
      await mount(tester);
      await openAddExpense(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Lunch',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '12.50',
      );
      await tester.tap(find.text('Food'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save expense'));
      await tester.pump();

      // Saving: the button is disabled and shows progress instead of its label.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      done.complete();
      await tester.pumpAndSettle();

      final saved =
          verify(() => repository.createExpense(captureAny())).captured.single
              as Expense;
      expect(saved.title, 'Lunch');
      expect(saved.amount, 12.5);
      expect(saved.category, ExpenseCategory.food);
      expect(saved.userId, 'user-1');
      expect(saved.id, 'new-expense-id');
      expect(find.text('Expense saved.'), findsOneWidget);
      // Back on the home shell (its app bar title is unique to that screen).
      expect(find.text('Expense Tracker'), findsOneWidget);
    },
  );

  testWidgets('repository failure surfaces an error and stays on the form', (
    tester,
  ) async {
    when(() => repository.createExpense(any())).thenThrow(
      const AppException(
        AppErrorCode.unavailable,
        'The service is temporarily unavailable. Try again.',
      ),
    );
    await mount(tester);
    await openAddExpense(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Lunch');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '10');
    await tester.tap(find.text('Food'));
    await tapSave(tester);
    expect(
      find.text('The service is temporarily unavailable. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Add expense'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
