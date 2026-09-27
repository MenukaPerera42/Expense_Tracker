import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_filter.dart';
import 'package:expense_tracker/domain/usecases/expense_search.dart';

Expense _expense({
  required String id,
  required String title,
  String? note,
  num amount = 10,
  DateTime? date,
  ExpenseCategory category = ExpenseCategory.food,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: amount,
  category: category,
  note: note,
  date: date ?? DateTime(2026, 9, 10),
  createdAt: date ?? DateTime(2026, 9, 10),
  updatedAt: date ?? DateTime(2026, 9, 10),
);

void main() {
  final expenses = [
    _expense(
      id: 'lunch',
      title: 'Team Lunch',
      note: 'With the design team',
      category: ExpenseCategory.food,
      date: DateTime(2026, 9, 5),
    ),
    _expense(
      id: 'bus',
      title: 'Bus fare',
      note: null,
      category: ExpenseCategory.transport,
      date: DateTime(2026, 9, 10),
    ),
    _expense(
      id: 'groceries',
      title: 'Groceries',
      note: 'Bought lunch ingredients for the week',
      category: ExpenseCategory.food,
      date: DateTime(2026, 8, 20),
    ),
  ];

  test('matches by title', () {
    final result = ExpenseSearchEngine.apply(expenses, 'Bus');
    expect(result.map((e) => e.id).toList(), ['bus']);
  });

  test('matches by note when the title does not match', () {
    final result = ExpenseSearchEngine.apply(expenses, 'design team');
    expect(result.map((e) => e.id).toList(), ['lunch']);
  });

  test('is case-insensitive', () {
    final result = ExpenseSearchEngine.apply(expenses, 'GROCERIES');
    expect(result.map((e) => e.id).toList(), ['groceries']);
  });

  test(
    'is whitespace-tolerant: extra/leading/trailing spaces in the query '
    'still match normally-spaced text',
    () {
      final result = ExpenseSearchEngine.apply(expenses, '   team    lunch  ');
      expect(result.map((e) => e.id).toList(), ['lunch']);
    },
  );

  test('a query matching neither title nor note returns no results', () {
    final result = ExpenseSearchEngine.apply(expenses, 'taxi');
    expect(result, isEmpty);
  });

  test('matches across both title and note for a shared term', () {
    // "lunch" appears in lunch's title and in groceries' note.
    final result = ExpenseSearchEngine.apply(expenses, 'lunch');
    expect(result.map((e) => e.id).toSet(), {'lunch', 'groceries'});
  });

  test('search composes with an active category filter', () {
    final filtered = ExpenseFilterEngine.apply(
      expenses,
      const ExpenseFilter().copyWithCategory(ExpenseCategory.food),
    );
    final result = ExpenseSearchEngine.apply(filtered, 'lunch');
    // Both food expenses mention "lunch", but "bus" (transport) is excluded
    // by the category filter regardless of what the search term is.
    expect(result.map((e) => e.id).toSet(), {'lunch', 'groceries'});
  });

  test('search composes with an active date filter', () {
    final filtered = ExpenseFilterEngine.apply(
      expenses,
      const ExpenseFilter().copyWithDate(DateTime(2026, 9, 5)),
    );
    final result = ExpenseSearchEngine.apply(filtered, 'lunch');
    // Groceries also matches "lunch" in its note, but falls outside the
    // exact-date filter, so only the Sept 5 expense survives both.
    expect(result.map((e) => e.id).toList(), ['lunch']);
  });

  test('clearing the search (empty query) returns the full input unfiltered', () {
    expect(ExpenseSearchEngine.apply(expenses, ''), expenses);
    expect(ExpenseSearchEngine.apply(expenses, '   '), expenses);
  });
}
