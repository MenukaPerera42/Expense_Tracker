import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

Expense _expense({
  required String id,
  required String title,
  required num amount,
  ExpenseCategory category = ExpenseCategory.food,
  String? note,
  DateTime? date,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: amount,
  category: category,
  note: note,
  date: date ?? DateTime.utc(2026, 9, 20),
  createdAt: DateTime.utc(2026, 9, 20),
  updatedAt: DateTime.utc(2026, 9, 20),
);

void main() {
  late MockExpenseRepository repository;

  setUpAll(() {
    registerFallbackValue(
      _expense(id: 'fallback', title: 'Fallback', amount: 1),
    );
  });

  setUp(() {
    repository = MockExpenseRepository();
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

  testWidgets(
    'loaded list shows date, category, title, amount and note indicator',
    (tester) async {
      final withNote = _expense(
        id: 'a',
        title: 'Team lunch',
        amount: 24.5,
        category: ExpenseCategory.food,
        note: 'With the design team',
        date: DateTime.utc(2026, 9, 25),
      );
      final withoutNote = _expense(
        id: 'b',
        title: 'Bus fare',
        amount: 3,
        category: ExpenseCategory.transport,
        date: DateTime.utc(2026, 9, 24),
      );
      when(
        () => repository.watchExpenses(),
      ).thenAnswer((_) => Stream.value([withNote, withoutNote]));
      await mount(tester);

      expect(find.text('Team lunch'), findsOneWidget);
      expect(find.text('Bus fare'), findsOneWidget);
      expect(
        find.text(CurrencyConfig.defaultCurrency.format(24.5)),
        findsOneWidget,
      );
      expect(
        find.text(CurrencyConfig.defaultCurrency.format(3)),
        findsOneWidget,
      );
      expect(
        find.text(
          'Food · ${DateFormat.yMMMd().format(withNote.date.toLocal())}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Transport · ${DateFormat.yMMMd().format(withoutNote.date.toLocal())}',
        ),
        findsOneWidget,
      );
      // Only the noted expense shows the note indicator.
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(find.byTooltip('Edit expense'), findsNWidgets(2));
      expect(find.byTooltip('Delete expense'), findsNWidgets(2));
    },
  );

  testWidgets('empty state offers an Add Expense action that opens the form', (
    tester,
  ) async {
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value(const []));
    await mount(tester);
    expect(find.text('No expenses yet'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
  });

  testWidgets('error state shows a message and a working retry', (
    tester,
  ) async {
    var calls = 0;
    when(() => repository.watchExpenses()).thenAnswer((_) {
      calls++;
      return Stream<List<Expense>>.error(
        const AppException(
          AppErrorCode.unavailable,
          'The service is temporarily unavailable. Try again.',
        ),
      );
    });
    await mount(tester);
    expect(
      find.text('The service is temporarily unavailable. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('delete asks for confirmation and does nothing on cancel', (
    tester,
  ) async {
    final expense = _expense(id: 'a', title: 'Team lunch', amount: 24.5);
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value([expense]));
    await mount(tester);
    await tester.tap(find.byTooltip('Delete expense'));
    await tester.pumpAndSettle();
    expect(find.text('Delete expense?'), findsOneWidget);
    expect(find.textContaining('Team lunch'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Team lunch'), findsOneWidget);
    verifyNever(() => repository.deleteExpense(any()));
  });

  testWidgets(
    'confirmed delete shows progress, then removes the row and confirms success',
    (tester) async {
      final expense = _expense(id: 'a', title: 'Team lunch', amount: 24.5);
      final listController = StreamController<List<Expense>>();
      addTearDown(listController.close);
      when(
        () => repository.watchExpenses(),
      ).thenAnswer((_) => listController.stream);
      final done = Completer<void>();
      when(
        () => repository.deleteExpense('a'),
      ).thenAnswer((_) => done.future);
      await mount(tester);
      listController.add([expense]);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();

      // Saving: the row dims and its delete button shows progress.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      done.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Expense deleted.'), findsOneWidget);

      // The row disappears once the stream re-emits — mirroring Firestore's
      // real-time update rather than an optimistic local removal.
      listController.add(const []);
      await tester.pumpAndSettle();
      expect(find.text('Team lunch'), findsNothing);
      expect(find.text('No expenses yet'), findsOneWidget);
      verify(() => repository.deleteExpense('a')).called(1);
    },
  );

  testWidgets(
    'failed delete surfaces an error, keeps the row, and re-enables retry',
    (tester) async {
      final expense = _expense(id: 'a', title: 'Team lunch', amount: 24.5);
      when(
        () => repository.watchExpenses(),
      ).thenAnswer((_) => Stream.value([expense]));
      when(() => repository.deleteExpense('a')).thenThrow(
        const AppException(
          AppErrorCode.unavailable,
          'The service is temporarily unavailable. Try again.',
        ),
      );
      await mount(tester);
      await tester.tap(find.byTooltip('Delete expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('The service is temporarily unavailable. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Team lunch'), findsOneWidget);
      expect(find.byTooltip('Delete expense'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.byTooltip('Delete expense')).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'edit action navigates to the edit screen and loads that expense',
    (tester) async {
      final expense = _expense(id: 'a', title: 'Team lunch', amount: 24.5);
      when(
        () => repository.watchExpenses(),
      ).thenAnswer((_) => Stream.value([expense]));
      when(
        () => repository.getExpenseById('a'),
      ).thenAnswer((_) async => expense);
      await mount(tester);
      await tester.tap(find.byTooltip('Edit expense'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Edit expense'), findsOneWidget);
      expect(find.text('Team lunch'), findsOneWidget);
    },
  );
}
