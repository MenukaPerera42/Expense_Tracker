import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/services/firebase_providers.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import 'auth_providers.dart';

final addExpenseControllerProvider =
    NotifierProvider.autoDispose<AddExpenseController, AsyncValue<void>>(
      AddExpenseController.new,
    );

/// Builds and saves a new [Expense] from already-validated primitive form
/// values. Parsing and repository access live here rather than in the
/// screen, so presentation never touches Firestore directly.
class AddExpenseController extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit({
    required String title,
    required String amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final userId = ref.read(authStateProvider).valueOrNull?.id;
      if (userId == null) {
        throw const AppException(
          AppErrorCode.unauthenticated,
          'Please sign in again.',
        );
      }
      final repository = await ref.read(expenseRepositoryProvider.future);
      final trimmedNote = note?.trim();
      final now = DateTime.now();
      final expense = Expense(
        id: repository.newExpenseId(),
        userId: userId,
        title: title.trim(),
        amount: double.parse(amount.trim()),
        category: category,
        date: date,
        // Timestamps are placeholders; the repository replaces both with
        // server timestamps on create (see ExpenseRepository.createExpense).
        note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createExpense(expense);
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(
        error is AppException
            ? error
            : const AppException(
                AppErrorCode.unknown,
                'Something went wrong. Please try again.',
              ),
        stack,
      );
    }
  }
}

String expenseErrorMessage(Object? error) => error is AppException
    ? error.message
    : 'Something went wrong. Please try again.';
