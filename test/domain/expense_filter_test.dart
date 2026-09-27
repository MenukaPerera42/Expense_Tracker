import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_filter.dart';

Expense _expense({
  required String id,
  required num amount,
  required DateTime date,
  ExpenseCategory category = ExpenseCategory.food,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: 'Expense $id',
  amount: amount,
  category: category,
  date: date,
  createdAt: date,
  updatedAt: date,
);

void main() {
  final expenses = [
    _expense(
      id: 'food-sep-5',
      amount: 20,
      date: DateTime(2026, 9, 5),
      category: ExpenseCategory.food,
    ),
    _expense(
      id: 'transport-sep-10',
      amount: 50,
      date: DateTime(2026, 9, 10),
      category: ExpenseCategory.transport,
    ),
    _expense(
      id: 'food-sep-20',
      amount: 5,
      date: DateTime(2026, 9, 20),
      category: ExpenseCategory.food,
    ),
    _expense(
      id: 'food-aug-15',
      amount: 100,
      date: DateTime(2026, 8, 15),
      category: ExpenseCategory.food,
    ),
  ];

  test('category filtering keeps only expenses in that category', () {
    final result = ExpenseFilterEngine.apply(
      expenses,
      const ExpenseFilter().copyWithCategory(ExpenseCategory.food),
    );
    expect(result.map((e) => e.id).toSet(), {
      'food-sep-5',
      'food-sep-20',
      'food-aug-15',
    });
  });

  test('date filtering keeps only expenses on that exact day', () {
    final result = ExpenseFilterEngine.apply(
      expenses,
      const ExpenseFilter().copyWithDate(DateTime(2026, 9, 10)),
    );
    expect(result.map((e) => e.id).toList(), ['transport-sep-10']);
  });

  test(
    'date range filtering keeps only expenses within the inclusive range',
    () {
      final result = ExpenseFilterEngine.apply(
        expenses,
        const ExpenseFilter().copyWithDateRange(
          DateRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 15)),
        ),
      );
      expect(result.map((e) => e.id).toSet(), {
        'food-sep-5',
        'transport-sep-10',
      });
    },
  );

  test('month filtering keeps only expenses in that calendar month', () {
    final result = ExpenseFilterEngine.apply(
      expenses,
      const ExpenseFilter().copyWithMonth(DateTime(2026, 8)),
    );
    expect(result.map((e) => e.id).toList(), ['food-aug-15']);
  });

  group('sorting', () {
    test('newest first orders by date descending', () {
      final result = ExpenseFilterEngine.apply(
        expenses,
        const ExpenseFilter().copyWithSort(ExpenseSortOption.newest),
      );
      expect(result.map((e) => e.id).toList(), [
        'food-sep-20',
        'transport-sep-10',
        'food-sep-5',
        'food-aug-15',
      ]);
    });

    test('oldest first orders by date ascending', () {
      final result = ExpenseFilterEngine.apply(
        expenses,
        const ExpenseFilter().copyWithSort(ExpenseSortOption.oldest),
      );
      expect(result.map((e) => e.id).toList(), [
        'food-aug-15',
        'food-sep-5',
        'transport-sep-10',
        'food-sep-20',
      ]);
    });

    test('highest amount first orders by amount descending', () {
      final result = ExpenseFilterEngine.apply(
        expenses,
        const ExpenseFilter().copyWithSort(ExpenseSortOption.highestAmount),
      );
      expect(result.map((e) => e.id).toList(), [
        'food-aug-15',
        'transport-sep-10',
        'food-sep-5',
        'food-sep-20',
      ]);
    });

    test('lowest amount first orders by amount ascending', () {
      final result = ExpenseFilterEngine.apply(
        expenses,
        const ExpenseFilter().copyWithSort(ExpenseSortOption.lowestAmount),
      );
      expect(result.map((e) => e.id).toList(), [
        'food-sep-20',
        'food-sep-5',
        'transport-sep-10',
        'food-aug-15',
      ]);
    });
  });

  test('combined filters: category + date range + sort all apply together', () {
    final filter = const ExpenseFilter()
        .copyWithCategory(ExpenseCategory.food)
        .copyWithDateRange(
          DateRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
        )
        .copyWithSort(ExpenseSortOption.highestAmount);
    final result = ExpenseFilterEngine.apply(expenses, filter);
    // Only food expenses in September, highest amount first.
    expect(result.map((e) => e.id).toList(), ['food-sep-5', 'food-sep-20']);
  });

  test('clearing filters returns to the unfiltered, default-sorted list', () {
    final filtered = const ExpenseFilter()
        .copyWithCategory(ExpenseCategory.transport)
        .copyWithMonth(DateTime(2026, 9));
    expect(filtered.isActive, isTrue);

    const cleared = ExpenseFilter.initial;
    expect(cleared.isActive, isFalse);
    expect(cleared.sort, ExpenseSortOption.newest);

    final result = ExpenseFilterEngine.apply(expenses, cleared);
    expect(result.length, expenses.length);
    expect(result.map((e) => e.id).toList(), [
      'food-sep-20',
      'transport-sep-10',
      'food-sep-5',
      'food-aug-15',
    ]);
  });

  test('a filter combination matching nothing returns an empty list', () {
    final filter = const ExpenseFilter()
        .copyWithCategory(ExpenseCategory.health)
        .copyWithMonth(DateTime(2026, 9));
    final result = ExpenseFilterEngine.apply(expenses, filter);
    expect(result, isEmpty);
  });

  test('setting a date clears any previously set date range or month, since '
      'the three date modes are mutually exclusive', () {
    final withRange = const ExpenseFilter().copyWithDateRange(
      DateRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)),
    );
    final withDate = withRange.copyWithDate(DateTime(2026, 9, 10));
    expect(withDate.dateRange, isNull);
    expect(withDate.date, DateTime(2026, 9, 10));

    final withMonth = withDate.copyWithMonth(DateTime(2026, 8));
    expect(withMonth.date, isNull);
    expect(withMonth.month, DateTime(2026, 8));
  });
}
