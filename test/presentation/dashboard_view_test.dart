import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

// Built off "now" (rather than a fixed calendar date) so these tests stay
// correct regardless of when they're actually run, since the dashboard's
// month selector and empty/current-month logic key off the real clock.
final _now = DateTime.now();
DateTime _thisMonth(int day) => DateTime.utc(_now.year, _now.month, day);
DateTime _previousMonth(int day) {
  final year = _now.month == 1 ? _now.year - 1 : _now.year;
  final month = _now.month == 1 ? 12 : _now.month - 1;
  return DateTime.utc(year, month, day);
}

Expense _expense({
  required String id,
  required String title,
  required num amount,
  required DateTime date,
  ExpenseCategory category = ExpenseCategory.food,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: amount,
  category: category,
  date: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  late MockExpenseRepository repository;

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

  testWidgets('shows the correct monthly total and transaction count', (
    tester,
  ) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Lunch', amount: 20, date: _thisMonth(5)),
        _expense(id: 'b', title: 'Bus', amount: 15.5, date: _thisMonth(10)),
        _expense(
          id: 'c',
          title: 'Old rent',
          amount: 999,
          date: _previousMonth(20),
        ),
      ]),
    );
    await mount(tester);

    expect(
      find.text(CurrencyConfig.defaultCurrency.format(35.5)),
      findsOneWidget,
    );
    expect(find.text('2 transactions'), findsOneWidget);
  });

  testWidgets('shows a per-category total', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(
          id: 'a',
          title: 'Lunch',
          amount: 20,
          date: _thisMonth(5),
          category: ExpenseCategory.food,
        ),
        _expense(
          id: 'b',
          title: 'Dinner',
          amount: 10,
          date: _thisMonth(6),
          category: ExpenseCategory.food,
        ),
        _expense(
          id: 'c',
          title: 'Bus',
          amount: 3,
          date: _thisMonth(7),
          category: ExpenseCategory.transport,
        ),
        _expense(
          id: 'd',
          title: 'Taxi',
          amount: 4,
          date: _thisMonth(8),
          category: ExpenseCategory.transport,
        ),
      ]),
    );
    await mount(tester);

    // Category totals (30 and 7) are distinct from every individual
    // expense's own amount (20, 10, 3, 4), so a single match confirms the
    // aggregated row rather than coincidentally matching a recent-list row.
    expect(find.text('Food'), findsOneWidget);
    expect(
      find.text(CurrencyConfig.defaultCurrency.format(30)),
      findsOneWidget,
    );
    expect(find.text('Transport'), findsOneWidget);
    expect(
      find.text(CurrencyConfig.defaultCurrency.format(7)),
      findsOneWidget,
    );
  });

  testWidgets('recent expenses are listed newest first', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Oldest', amount: 1, date: _thisMonth(2)),
        _expense(id: 'b', title: 'Newest', amount: 1, date: _thisMonth(28)),
        _expense(id: 'c', title: 'Middle', amount: 1, date: _thisMonth(15)),
      ]),
    );
    await mount(tester);

    final newestY = tester.getTopLeft(find.text('Newest')).dy;
    final middleY = tester.getTopLeft(find.text('Middle')).dy;
    final oldestY = tester.getTopLeft(find.text('Oldest')).dy;
    expect(newestY, lessThan(middleY));
    expect(middleY, lessThan(oldestY));
  });

  testWidgets('an empty month shows the empty state instead of a breakdown', (
    tester,
  ) async {
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value(const []));
    await mount(tester);

    expect(find.textContaining('No expenses in'), findsOneWidget);
    expect(find.text('Spending by category'), findsNothing);
    expect(
      find.text(CurrencyConfig.defaultCurrency.format(0)),
      findsOneWidget,
    );
  });

  testWidgets(
    'navigating to the previous month shows that month\'s data, and '
    'switching months never triggers another Firestore read',
    (tester) async {
      when(() => repository.watchExpenses()).thenAnswer(
        (_) => Stream.value([
          _expense(id: 'a', title: 'This month', amount: 20, date: _thisMonth(5)),
          _expense(
            id: 'b',
            title: 'Last month',
            amount: 999,
            date: _previousMonth(20),
          ),
        ]),
      );
      await mount(tester);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Last month'), findsNothing);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();

      expect(find.text('Last month'), findsOneWidget);
      expect(find.text('This month'), findsNothing);
      expect(
        find.text(CurrencyConfig.defaultCurrency.format(999)),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('This month'), findsOneWidget);

      // "Next" is disabled once back at the current month.
      expect(
        tester.widget<IconButton>(find.byTooltip('Next month')).onPressed,
        isNull,
      );

      // A single subscription serves every month switch above.
      verify(() => repository.watchExpenses()).called(1);
    },
  );
}
