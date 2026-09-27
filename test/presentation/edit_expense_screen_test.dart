import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/screens/edit_expense_screen.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

Expense _expense({
  String id = 'a',
  String title = 'Team lunch',
  num amount = 24.5,
  ExpenseCategory category = ExpenseCategory.food,
  String? note = 'With the design team',
  DateTime? date,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: amount,
  category: category,
  note: note,
  date: date ?? DateTime.utc(2026, 9, 20),
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, 1),
);

void main() {
  late MockExpenseRepository repository;

  setUpAll(() {
    registerFallbackValue(_expense());
  });

  setUp(() {
    repository = MockExpenseRepository();
  });

  /// Pushes EditExpenseScreen on top of a placeholder root route, so pop
  /// behavior (success, "not found" -> Go back, and the discard dialog) can
  /// be verified against a real Navigator stack instead of just checking
  /// text on screen.
  Future<void> openEditor(
    WidgetTester tester, {
    required String id,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditExpenseScreen(expenseId: id),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('loading state shows a spinner while the expense is fetched', (
    tester,
  ) async {
    final completer = Completer<Expense?>();
    when(() => repository.getExpenseById('a'))
        .thenAnswer((_) => completer.future);
    await openEditor(tester, id: 'a', settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_expense());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Team lunch'), findsOneWidget);
  });

  testWidgets('missing expense shows a not-found state and can go back', (
    tester,
  ) async {
    when(() => repository.getExpenseById('missing'))
        .thenAnswer((_) async => null);
    await openEditor(tester, id: 'missing');
    expect(find.text('Expense not found'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('Open editor'), findsOneWidget);
  });

  testWidgets('existing data loads into every field', (tester) async {
    final expense = _expense(
      title: 'Team lunch',
      amount: 24.5,
      category: ExpenseCategory.food,
      note: 'With the design team',
    );
    when(() => repository.getExpenseById('a')).thenAnswer((_) async => expense);
    await openEditor(tester, id: 'a');

    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('24.5'), findsOneWidget);
    expect(find.text('With the design team'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Food'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Transport'))
          .selected,
      isFalse,
    );
  });

  testWidgets('field changes are reflected back in the form', (tester) async {
    when(() => repository.getExpenseById('a'))
        .thenAnswer((_) async => _expense());
    await openEditor(tester, id: 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '50');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.pump();
    expect(find.text('50'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Transport'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Food'))
          .selected,
      isFalse,
    );
  });

  testWidgets('clearing the title blocks submission with a validation error', (
    tester,
  ) async {
    when(() => repository.getExpenseById('a'))
        .thenAnswer((_) async => _expense());
    await openEditor(tester, id: 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), '');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a title.'), findsOneWidget);
    verifyNever(() => repository.updateExpense(any()));
  });

  testWidgets(
    'successful update shows a saving state, then confirms and returns',
    (tester) async {
      final expense = _expense();
      when(() => repository.getExpenseById('a'))
          .thenAnswer((_) async => expense);
      final done = Completer<void>();
      when(() => repository.updateExpense(any()))
          .thenAnswer((_) => done.future);
      await openEditor(tester, id: 'a');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '30',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Save changes'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      done.complete();
      await tester.pumpAndSettle();

      final saved =
          verify(() => repository.updateExpense(captureAny())).captured.single
              as Expense;
      // Immutable fields preserved from the original.
      expect(saved.id, expense.id);
      expect(saved.userId, expense.userId);
      expect(saved.createdAt, expense.createdAt);
      // Edited field applied.
      expect(saved.amount, 30);
      expect(find.text('Changes saved.'), findsOneWidget);
      expect(find.text('Open editor'), findsOneWidget);
    },
  );

  testWidgets('failed update surfaces an error and stays on the form', (
    tester,
  ) async {
    when(() => repository.getExpenseById('a'))
        .thenAnswer((_) async => _expense());
    when(() => repository.updateExpense(any())).thenThrow(
      const AppException(
        AppErrorCode.unavailable,
        'The service is temporarily unavailable. Try again.',
      ),
    );
    await openEditor(tester, id: 'a');
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '30');
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save changes'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    expect(
      find.text('The service is temporarily unavailable. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Open editor'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'leaving with unsaved changes asks for confirmation before discarding',
    (tester) async {
      when(() => repository.getExpenseById('a'))
          .thenAnswer((_) async => _expense());
      await openEditor(tester, id: 'a');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'),
        '99',
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsNothing);
      expect(find.text('99'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      verifyNever(() => repository.updateExpense(any()));
    },
  );
}
