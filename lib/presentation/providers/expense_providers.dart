import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/services/firebase_providers.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import 'auth_providers.dart';

/// Newest-first live view of the signed-in user's expenses. A plain
/// (non-autoDispose) StreamProvider, matching authStateProvider, so
/// navigating to Add/Edit and back does not restart the Firestore listener.
final expenseListProvider = StreamProvider<List<Expense>>((ref) async* {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  yield* repository.watchExpenses();
});

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

final deleteExpenseControllerProvider = NotifierProvider<
  DeleteExpenseController,
  Map<String, AsyncValue<void>>
>(DeleteExpenseController.new);

/// Tracks the in-flight/last delete result keyed by expense ID, so each row
/// in the history list can show its own loading/error state independently
/// (via `.select`) instead of the whole list rebuilding on every delete.
class DeleteExpenseController extends Notifier<Map<String, AsyncValue<void>>> {
  @override
  Map<String, AsyncValue<void>> build() => const {};

  Future<void> delete(String id) async {
    if (state[id]?.isLoading == true) return;
    state = {...state, id: const AsyncLoading()};
    try {
      final repository = await ref.read(expenseRepositoryProvider.future);
      await repository.deleteExpense(id);
      state = {...state, id: const AsyncData(null)};
    } catch (error, stack) {
      state = {
        ...state,
        id: AsyncError(
          error is AppException
              ? error
              : const AppException(
                  AppErrorCode.unknown,
                  'Something went wrong. Please try again.',
                ),
          stack,
        ),
      };
    }
  }

  /// Drops a finished (success or error) result once it has been shown, so a
  /// later delete of the same ID — or, after re-adding, the rare ID reuse
  /// case — starts from a clean state instead of replaying stale feedback.
  void clear(String id) {
    if (!state.containsKey(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }
}

String expenseErrorMessage(Object? error) => error is AppException
    ? error.message
    : 'Something went wrong. Please try again.';
