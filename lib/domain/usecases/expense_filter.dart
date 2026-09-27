import '../entities/expense.dart';
import '../entities/expense_category.dart';
import 'month_navigation.dart';

enum ExpenseSortOption {
  newest('Newest first'),
  oldest('Oldest first'),
  highestAmount('Highest amount'),
  lowestAmount('Lowest amount');

  const ExpenseSortOption(this.label);
  final String label;
}

/// An inclusive, closed range of whole calendar days (local time). Its own
/// type rather than a raw pair of [DateTime]s, so "does this expense fall
/// inside the range" has exactly one place to be correct.
final class DateRange {
  DateRange({required DateTime start, required DateTime end})
    : assert(!end.isBefore(start), 'end must not precede start'),
      start = _startOfDay(start),
      end = _startOfDay(end);

  final DateTime start;
  final DateTime end;

  static DateTime _startOfDay(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool contains(DateTime date) {
    final day = _startOfDay(date);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Immutable filter/sort state for the expense history list. `category`,
/// `date`, `dateRange` and `month` are independent, optional constraints —
/// every one that is set must match for an expense to appear — so any
/// combination (e.g. category + a date range, plus a sort order) works
/// together without special-casing.
final class ExpenseFilter {
  const ExpenseFilter({
    this.category,
    this.date,
    this.dateRange,
    this.month,
    this.sort = ExpenseSortOption.newest,
  });

  final ExpenseCategory? category;
  final DateTime? date;
  final DateRange? dateRange;
  final DateTime? month;
  final ExpenseSortOption sort;

  /// Whether any constraint (beyond sort order) is currently applied.
  bool get isActive =>
      category != null || date != null || dateRange != null || month != null;

  ExpenseFilter copyWithCategory(ExpenseCategory? category) =>
      ExpenseFilter(category: category, date: date, dateRange: dateRange, month: month, sort: sort);

  /// Setting an exact date clears the range/month filters — the three date
  /// modes are mutually exclusive in the UI, so only one is ever active.
  ExpenseFilter copyWithDate(DateTime? date) => ExpenseFilter(
    category: category,
    date: date,
    dateRange: date == null ? dateRange : null,
    month: date == null ? month : null,
    sort: sort,
  );

  ExpenseFilter copyWithDateRange(DateRange? dateRange) => ExpenseFilter(
    category: category,
    date: dateRange == null ? date : null,
    dateRange: dateRange,
    month: dateRange == null ? month : null,
    sort: sort,
  );

  ExpenseFilter copyWithMonth(DateTime? month) => ExpenseFilter(
    category: category,
    date: month == null ? date : null,
    dateRange: month == null ? dateRange : null,
    month: month == null ? null : MonthNavigation.normalize(month),
    sort: sort,
  );

  ExpenseFilter copyWithSort(ExpenseSortOption sort) => ExpenseFilter(
    category: category,
    date: date,
    dateRange: dateRange,
    month: month,
    sort: sort,
  );

  /// Resets every constraint, including sort order, back to defaults.
  static const initial = ExpenseFilter();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseFilter &&
          category == other.category &&
          date == other.date &&
          dateRange == other.dateRange &&
          month == other.month &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(category, date, dateRange, month, sort);
}

/// Pure filter + sort logic, kept out of any widget or provider so it can be
/// unit tested directly against plain lists of [Expense].
abstract final class ExpenseFilterEngine {
  static List<Expense> apply(List<Expense> expenses, ExpenseFilter filter) {
    final filtered = expenses.where((expense) => _matches(expense, filter)).toList();
    filtered.sort(_comparatorFor(filter.sort));
    return filtered;
  }

  static bool _matches(Expense expense, ExpenseFilter filter) {
    if (filter.category != null && expense.category != filter.category) {
      return false;
    }
    if (filter.date != null && !_isSameDay(expense.date, filter.date!)) {
      return false;
    }
    if (filter.dateRange != null && !filter.dateRange!.contains(expense.date)) {
      return false;
    }
    if (filter.month != null &&
        !MonthNavigation.isSameMonth(expense.date, filter.month!)) {
      return false;
    }
    return true;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static int Function(Expense, Expense) _comparatorFor(ExpenseSortOption sort) {
    switch (sort) {
      case ExpenseSortOption.newest:
        return (a, b) => b.date.compareTo(a.date);
      case ExpenseSortOption.oldest:
        return (a, b) => a.date.compareTo(b.date);
      case ExpenseSortOption.highestAmount:
        return (a, b) => b.amount.compareTo(a.amount);
      case ExpenseSortOption.lowestAmount:
        return (a, b) => a.amount.compareTo(b.amount);
    }
  }
}
