import '../entities/expense.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpenses({bool descending = true});

  /// Returns null when the document does not exist.
  Future<Expense?> getExpenseById(String id);
  Stream<List<Expense>> watchExpenses({bool descending = true});

  /// Caller supplies a stable ID. Existing IDs fail instead of overwriting.
  /// Audit timestamps in the input are ignored in favor of server timestamps.
  Future<void> createExpense(Expense expense);

  /// Preserves stored createdAt; missing documents fail with notFound.
  Future<void> updateExpense(Expense expense);

  /// Missing documents fail with notFound.
  Future<void> deleteExpense(String id);
}
