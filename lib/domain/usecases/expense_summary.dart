import '../entities/expense.dart';
import '../entities/expense_category.dart';
import 'month_navigation.dart';

/// Aggregate figures for a single month, computed entirely from an
/// already-loaded list of expenses. Building one never issues a query of
/// its own, so switching the dashboard's selected month costs no extra
/// Firestore read — only re-aggregation of data the app already has.
final class MonthlyExpenseSummary {
  MonthlyExpenseSummary({
    required this.month,
    required this.total,
    required this.transactionCount,
    required Map<ExpenseCategory, double> categoryTotals,
    required List<Expense> recentExpenses,
  }) : categoryTotals = Map.unmodifiable(categoryTotals),
       recentExpenses = List.unmodifiable(recentExpenses);

  /// The first instant of the summarized month (see [MonthNavigation.normalize]).
  final DateTime month;
  final double total;
  final int transactionCount;
  final Map<ExpenseCategory, double> categoryTotals;

  /// The most recent expenses in [month], newest first, capped at
  /// [ExpenseSummaryCalculator.recentLimit].
  final List<Expense> recentExpenses;

  bool get isEmpty => transactionCount == 0;
}

abstract final class ExpenseSummaryCalculator {
  static const recentLimit = 5;

  /// Filters [expenses] to those whose *expense date* — never `createdAt`
  /// or `updatedAt` — falls within [month], then aggregates the total,
  /// transaction count, per-category totals, and most recent expenses.
  static MonthlyExpenseSummary summarize(
    List<Expense> expenses, {
    required DateTime month,
  }) {
    final normalizedMonth = MonthNavigation.normalize(month);
    final inMonth = expenses
        .where(
          (expense) =>
              MonthNavigation.isSameMonth(expense.date, normalizedMonth),
        )
        .toList();

    var total = 0.0;
    final categoryTotals = <ExpenseCategory, double>{};
    for (final expense in inMonth) {
      total += expense.amount;
      categoryTotals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    // Re-sorted here rather than trusted from the caller, so this stays
    // correct even if it's ever fed a list that isn't already newest-first.
    final recent = [...inMonth]..sort((a, b) => b.date.compareTo(a.date));

    return MonthlyExpenseSummary(
      month: normalizedMonth,
      total: total,
      transactionCount: inMonth.length,
      categoryTotals: categoryTotals,
      recentExpenses: recent.take(recentLimit).toList(),
    );
  }
}
