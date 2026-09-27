import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_summary.dart';

Expense _expense({
  required String id,
  required num amount,
  required DateTime date,
  ExpenseCategory category = ExpenseCategory.food,
  DateTime? createdAt,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: 'Expense $id',
  amount: amount,
  category: category,
  date: date,
  createdAt: createdAt ?? date,
  updatedAt: createdAt ?? date,
);

void main() {
  final month = DateTime(2026, 9);

  test('total is the sum of amounts for expenses within the month', () {
    final expenses = [
      _expense(id: 'a', amount: 20, date: DateTime(2026, 9, 5)),
      _expense(id: 'b', amount: 15.5, date: DateTime(2026, 9, 28)),
      _expense(id: 'c', amount: 999, date: DateTime(2026, 8, 30)),
    ];
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.total, 35.5);
  });

  test('transaction count only includes expenses within the month', () {
    final expenses = [
      _expense(id: 'a', amount: 20, date: DateTime(2026, 9, 5)),
      _expense(id: 'b', amount: 15, date: DateTime(2026, 9, 28)),
      _expense(id: 'c', amount: 999, date: DateTime(2026, 10, 1)),
    ];
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.transactionCount, 2);
  });

  test('category totals aggregate by category within the month', () {
    final expenses = [
      _expense(
        id: 'a',
        amount: 20,
        date: DateTime(2026, 9, 5),
        category: ExpenseCategory.food,
      ),
      _expense(
        id: 'b',
        amount: 10,
        date: DateTime(2026, 9, 6),
        category: ExpenseCategory.food,
      ),
      _expense(
        id: 'c',
        amount: 5,
        date: DateTime(2026, 9, 7),
        category: ExpenseCategory.transport,
      ),
    ];
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.categoryTotals[ExpenseCategory.food], 30);
    expect(summary.categoryTotals[ExpenseCategory.transport], 5);
    expect(summary.categoryTotals.containsKey(ExpenseCategory.bills), isFalse);
  });

  test('an empty month reports zero total, zero count, and no recents', () {
    final expenses = [
      _expense(id: 'a', amount: 20, date: DateTime(2026, 8, 5)),
    ];
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.isEmpty, isTrue);
    expect(summary.total, 0);
    expect(summary.transactionCount, 0);
    expect(summary.categoryTotals, isEmpty);
    expect(summary.recentExpenses, isEmpty);
  });

  test('membership is decided by expense.date, never createdAt/updatedAt', () {
    final expenses = [
      // Dated in September but originally recorded (createdAt) in August.
      _expense(
        id: 'a',
        amount: 20,
        date: DateTime(2026, 9, 5),
        createdAt: DateTime(2026, 8, 1),
      ),
      // Dated in August even though it was entered (createdAt) in September.
      _expense(
        id: 'b',
        amount: 999,
        date: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 9, 10),
      ),
    ];
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.transactionCount, 1);
    expect(summary.total, 20);
    expect(summary.recentExpenses.single.id, 'a');
  });

  test(
    'recent expenses are ordered newest first regardless of input order',
    () {
      final expenses = [
        _expense(id: 'oldest', amount: 1, date: DateTime(2026, 9, 2)),
        _expense(id: 'newest', amount: 1, date: DateTime(2026, 9, 28)),
        _expense(id: 'middle', amount: 1, date: DateTime(2026, 9, 15)),
      ];
      final summary = ExpenseSummaryCalculator.summarize(
        expenses,
        month: month,
      );
      expect(summary.recentExpenses.map((expense) => expense.id).toList(), [
        'newest',
        'middle',
        'oldest',
      ]);
    },
  );

  test('recent expenses are capped at recentLimit', () {
    final expenses = List.generate(
      8,
      (i) => _expense(id: 'e$i', amount: 1, date: DateTime(2026, 9, 1 + i)),
    );
    final summary = ExpenseSummaryCalculator.summarize(expenses, month: month);
    expect(summary.recentExpenses.length, ExpenseSummaryCalculator.recentLimit);
    // The five most recent of the eight (days 4..8 of September, newest first).
    expect(summary.recentExpenses.map((expense) => expense.id).toList(), [
      'e7',
      'e6',
      'e5',
      'e4',
      'e3',
    ]);
  });
}
