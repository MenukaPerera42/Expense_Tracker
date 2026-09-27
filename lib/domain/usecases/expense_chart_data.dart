import '../entities/expense.dart';
import '../entities/expense_category.dart';
import 'expense_summary.dart';
import 'month_navigation.dart';

/// One category's share of a chart, pre-computed so chart widgets never
/// need to know how a percentage or a color mapping is derived.
final class CategorySlice {
  const CategorySlice({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  final ExpenseCategory category;
  final double amount;

  /// This category's share of the chart's total, in the range `0.0`–`1.0`.
  /// `0` when the chart's total is `0` (avoids a division by zero rather
  /// than reporting an undefined share).
  final double percentage;
}

// (MonthlySpendingPoint moved to bottom)

/// Pure transformations from already-loaded expense data to chart-ready
/// shapes. No widget, provider, or Firestore dependency — chart widgets
/// consume [CategorySlice]/[MonthlySpendingPoint], never a repository or a
/// raw expense list, so they can be previewed, tested, or reused against
/// any data source.
abstract final class ExpenseChartData {
  /// Turns a category→total map (e.g. [MonthlyExpenseSummary.categoryTotals])
  /// into slices sorted by spend, highest first, each with its share of the
  /// combined total. An empty map yields an empty list — the zero-data case
  /// a chart widget renders as its own empty state, not a divide-by-zero.
  static List<CategorySlice> categorySlices(
    Map<ExpenseCategory, double> categoryTotals,
  ) {
    final total = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final entry in entries)
        CategorySlice(
          category: entry.key,
          amount: entry.value,
          percentage: total > 0 ? entry.value / total : 0,
        ),
    ];
  }

  /// Monthly totals for the `monthsBack` months up to and including
  /// [endMonth], oldest first — the shape a trend/bar chart wants. Each
  /// total is computed by re-running [ExpenseSummaryCalculator.summarize]
  /// against the same already-loaded [expenses] for that month, so a
  /// month with no expenses simply reports a total of `0` rather than being
  /// left out of the series.
  static List<MonthlySpendingPoint> monthlySpending(
    List<Expense> expenses, {
    required DateTime endMonth,
    int monthsBack = 6,
  }) {
    assert(monthsBack > 0, 'monthsBack must be positive');
    final months = <DateTime>[];
    var cursor = MonthNavigation.normalize(endMonth);
    for (var i = 0; i < monthsBack; i++) {
      months.add(cursor);
      cursor = MonthNavigation.previous(cursor);
    }
    return [
      for (final month in months.reversed)
        MonthlySpendingPoint(
          month: month,
          total: ExpenseSummaryCalculator.summarize(
            expenses,
            month: month,
          ).total,
        ),
    ];
  }

  static List<DailySpendingPoint> dailySpending(
    List<Expense> expenses, {
    required DateTime month,
  }) {
    final start = MonthNavigation.normalize(month);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final Map<int, double> totals = {
      for (var i = 1; i <= daysInMonth; i++) i: 0.0,
    };

    for (final e in expenses) {
      if (e.date.year == start.year && e.date.month == start.month) {
        totals[e.date.day] = (totals[e.date.day] ?? 0) + e.amount;
      }
    }

    return [
      for (var i = 1; i <= daysInMonth; i++)
        DailySpendingPoint(
          day: i,
          date: DateTime(start.year, start.month, i),
          total: totals[i]!,
        ),
    ];
  }

  static List<WeeklySpendingPoint> weeklySpending(
    List<Expense> expenses, {
    required DateTime month,
  }) {
    final start = MonthNavigation.normalize(month);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final numWeeks = (daysInMonth / 7).ceil();
    final Map<int, double> totals = {
      for (var i = 1; i <= numWeeks; i++) i: 0.0,
    };

    for (final e in expenses) {
      if (e.date.year == start.year && e.date.month == start.month) {
        final week = ((e.date.day - 1) ~/ 7) + 1;
        totals[week] = (totals[week] ?? 0) + e.amount;
      }
    }

    return [
      for (var i = 1; i <= numWeeks; i++)
        WeeklySpendingPoint(week: i, total: totals[i]!),
    ];
  }
}

abstract class SpendingPoint {
  double get total;
}

final class MonthlySpendingPoint implements SpendingPoint {
  const MonthlySpendingPoint({required this.month, required this.total});
  final DateTime month;
  @override
  final double total;
}

final class DailySpendingPoint implements SpendingPoint {
  const DailySpendingPoint({
    required this.day,
    required this.date,
    required this.total,
  });
  final int day;
  final DateTime date;
  @override
  final double total;
}

final class WeeklySpendingPoint implements SpendingPoint {
  const WeeklySpendingPoint({required this.week, required this.total});
  final int week;
  @override
  final double total;
}
