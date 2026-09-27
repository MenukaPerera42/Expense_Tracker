import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_chart_data.dart';

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
  group('categorySlices (category aggregation / totals)', () {
    test('aggregates a category total map into sorted, percentaged slices', () {
      final slices = ExpenseChartData.categorySlices({
        ExpenseCategory.food: 30,
        ExpenseCategory.transport: 10,
      });
      expect(slices.map((s) => s.category).toList(), [
        ExpenseCategory.food,
        ExpenseCategory.transport,
      ]);
      expect(slices[0].amount, 30);
      expect(slices[0].percentage, closeTo(0.75, 1e-9));
      expect(slices[1].amount, 10);
      expect(slices[1].percentage, closeTo(0.25, 1e-9));
    });

    test('a single category is its own 100% slice', () {
      final slices = ExpenseChartData.categorySlices({
        ExpenseCategory.health: 42,
      });
      expect(slices, hasLength(1));
      expect(slices.single.category, ExpenseCategory.health);
      expect(slices.single.percentage, 1.0);
    });

    test('many categories are all represented and sum to 100%', () {
      final totals = {
        for (final category in ExpenseCategory.values)
          category: (category.index + 1) * 10.0,
      };
      final slices = ExpenseChartData.categorySlices(totals);
      expect(slices, hasLength(ExpenseCategory.values.length));
      final percentageSum = slices.fold<double>(0, (a, s) => a + s.percentage);
      expect(percentageSum, closeTo(1.0, 1e-9));
      // Sorted highest amount first.
      for (var i = 1; i < slices.length; i++) {
        expect(slices[i - 1].amount, greaterThanOrEqualTo(slices[i].amount));
      }
    });

    test(
      'an empty category map is the zero-data case: an empty slice list',
      () {
        expect(ExpenseChartData.categorySlices(const {}), isEmpty);
      },
    );

    test('large amounts are represented exactly, with correct percentages', () {
      final slices = ExpenseChartData.categorySlices({
        ExpenseCategory.bills: 999999.99,
        ExpenseCategory.food: 0.01,
      });
      expect(slices[0].amount, 999999.99);
      expect(slices[0].percentage, closeTo(0.99999999, 1e-6));
    });
  });

  group('monthlySpending (selected month data / chart transformation)', () {
    test('reports the correct total for the selected (end) month', () {
      final expenses = [
        _expense(id: 'a', amount: 20, date: DateTime(2026, 9, 5)),
        _expense(id: 'b', amount: 15, date: DateTime(2026, 9, 20)),
        _expense(id: 'c', amount: 999, date: DateTime(2026, 8, 1)),
      ];
      final points = ExpenseChartData.monthlySpending(
        expenses,
        endMonth: DateTime(2026, 9),
        monthsBack: 1,
      );
      expect(points, hasLength(1));
      expect(points.single.month, DateTime(2026, 9));
      expect(points.single.total, 35);
    });

    test('returns monthsBack points, oldest first, ending at endMonth', () {
      final points = ExpenseChartData.monthlySpending(
        const [],
        endMonth: DateTime(2026, 9),
        monthsBack: 3,
      );
      expect(points.map((p) => p.month).toList(), [
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
      ]);
    });

    test('a month with no expenses reports a total of zero (zero-state)', () {
      final points = ExpenseChartData.monthlySpending(
        const [],
        endMonth: DateTime(2026, 9),
        monthsBack: 2,
      );
      expect(points.every((p) => p.total == 0), isTrue);
    });

    test('each point matches ExpenseSummaryCalculator\'s total for that month '
        '(the same transformation the dashboard total card relies on)', () {
      final expenses = [
        _expense(id: 'a', amount: 10, date: DateTime(2026, 7, 15)),
        _expense(id: 'b', amount: 25, date: DateTime(2026, 8, 3)),
        _expense(id: 'c', amount: 5, date: DateTime(2026, 8, 28)),
      ];
      final points = ExpenseChartData.monthlySpending(
        expenses,
        endMonth: DateTime(2026, 8),
        monthsBack: 2,
      );
      expect(points[0].total, 10); // July
      expect(points[1].total, 30); // August
    });
  });
}
