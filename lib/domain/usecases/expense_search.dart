import '../entities/expense.dart';

/// Case-insensitive, whitespace-tolerant substring search over an expense's
/// title and note. Pure — no widgets, no providers, no Firestore — so it
/// can run against the already-loaded expense list on every keystroke
/// (after a small debounce upstream) without issuing any query.
abstract final class ExpenseSearchEngine {
  static List<Expense> apply(List<Expense> expenses, String query) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return expenses;
    return expenses
        .where(
          (expense) =>
              matches(expense, normalizedQuery, alreadyNormalized: true),
        )
        .toList();
  }

  static bool matches(
    Expense expense,
    String query, {
    bool alreadyNormalized = false,
  }) {
    final normalizedQuery = alreadyNormalized ? query : normalize(query);
    if (normalizedQuery.isEmpty) return true;
    final title = normalize(expense.title);
    final note = expense.note == null ? '' : normalize(expense.note!);
    return title.contains(normalizedQuery) || note.contains(normalizedQuery);
  }

  /// Lowercases, trims the ends, and collapses any run of whitespace to a
  /// single space, applied to both the query and the text it's matched
  /// against — so "  Team   Lunch " (typed) matches "Team Lunch" (stored)
  /// and vice versa, regardless of case or incidental extra spacing.
  static String normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
