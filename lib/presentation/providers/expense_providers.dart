import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/services/firebase_providers.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_chart_data.dart';
import '../../domain/usecases/expense_filter.dart';
import '../../domain/usecases/expense_search.dart';
import '../../domain/usecases/expense_summary.dart';
import '../../domain/usecases/month_navigation.dart';
import 'auth_providers.dart';

/// Newest-first live view of the signed-in user's expenses. A plain
/// (non-autoDispose) StreamProvider, matching authStateProvider, so
/// navigating to Add/Edit and back does not restart the Firestore listener.
final expenseListProvider = StreamProvider<List<Expense>>((ref) async* {
  final repository = await ref.watch(expenseRepositoryProvider.future);
  yield* repository.watchExpenses();
});

/// A single expense by ID, fetched fresh each time the edit screen opens
/// (autoDispose + family) rather than reused from wherever the caller
/// navigated from — so editing always starts from the server's current
/// data and can genuinely detect "this was deleted since the list loaded".
final expenseByIdProvider = FutureProvider.autoDispose.family<Expense?, String>(
  (ref, id) async {
    final repository = await ref.watch(expenseRepositoryProvider.future);
    return repository.getExpenseById(id);
  },
);

final addExpenseControllerProvider =
    NotifierProvider.autoDispose<AddExpenseController, AsyncValue<void>>(
      AddExpenseController.new,
    );

/// Builds and saves a new [Expense] from already-validated primitive form
/// values. Parsing and repository access live here rather than in the
/// screen, so presentation never touches Firestore directly.
class AddExpenseController extends Notifier<AsyncValue<void>> {
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
      final userId = ref.read(authStateProvider).value?.id;
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

final editExpenseControllerProvider =
    NotifierProvider.autoDispose<EditExpenseController, AsyncValue<void>>(
      EditExpenseController.new,
    );

/// Saves changes to an already-loaded [Expense]. The ID, owner and
/// createdAt come from [original] rather than the form, so immutable
/// fields can never be altered by editing; the repository additionally
/// enforces this server-side (updateExpense strips id/userId/createdAt from
/// the write and stamps updatedAt with a server timestamp).
class EditExpenseController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> submit({
    required Expense original,
    required String title,
    required String amount,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final repository = await ref.read(expenseRepositoryProvider.future);
      final trimmedNote = note?.trim();
      final updated = Expense(
        id: original.id,
        userId: original.userId,
        title: title.trim(),
        amount: double.parse(amount.trim()),
        category: category,
        date: date,
        note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
        createdAt: original.createdAt,
        // Placeholder to keep the entity's own invariant (updatedAt >=
        // createdAt) satisfied; the repository replaces it with a server
        // timestamp on write, same as create.
        updatedAt: DateTime.now(),
      );
      await repository.updateExpense(updated);
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

final deleteExpenseControllerProvider =
    NotifierProvider<DeleteExpenseController, Map<String, AsyncValue<void>>>(
      DeleteExpenseController.new,
    );

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

/// The month currently shown on the dashboard.
final selectedMonthProvider =
    NotifierProvider<SelectedMonthController, DateTime>(
      SelectedMonthController.new,
    );

/// Defaults to the current month and only ever holds a normalized
/// (first-of-month) value. Navigation is capped so the dashboard can never
/// be pushed into a month that hasn't happened yet.
class SelectedMonthController extends Notifier<DateTime> {
  @override
  DateTime build() => MonthNavigation.normalize(DateTime.now());

  void previousMonth() => state = MonthNavigation.previous(state);

  void nextMonth() => state = MonthNavigation.next(state);
}

/// The dashboard's monthly summary for [selectedMonthProvider], derived
/// entirely from [expenseListProvider]'s already-loaded data. This is a
/// plain synchronous [Provider] — not a new stream or future — so changing
/// the selected month only re-aggregates data already held in memory and
/// never triggers another Firestore read.
final monthlyExpenseSummaryProvider =
    Provider<AsyncValue<MonthlyExpenseSummary>>((ref) {
      final month = ref.watch(selectedMonthProvider);
      final expenses = ref.watch(expenseListProvider);
      return expenses.whenData(
        (list) => ExpenseSummaryCalculator.summarize(list, month: month),
      );
    });

/// The expense history screen's active filter/sort state.
final expenseFilterProvider =
    NotifierProvider<ExpenseFilterController, ExpenseFilter>(
      ExpenseFilterController.new,
    );

/// A thin wrapper around [ExpenseFilter]'s own immutable `copyWith*`
/// methods — the state itself carries the mutual-exclusion rules (setting a
/// date clears any range/month, and vice versa), so this controller only
/// ever replaces `state` with what the model already computed.
class ExpenseFilterController extends Notifier<ExpenseFilter> {
  @override
  ExpenseFilter build() => ExpenseFilter.initial;

  void setCategory(ExpenseCategory? category) =>
      state = state.copyWithCategory(category);

  void setDate(DateTime? date) => state = state.copyWithDate(date);

  void setDateRange(DateRange? range) => state = state.copyWithDateRange(range);

  void setMonth(DateTime? month) => state = state.copyWithMonth(month);

  void setSort(ExpenseSortOption sort) => state = state.copyWithSort(sort);

  void clear() => state = ExpenseFilter.initial;
}

/// The expense history screen's current search text (title/note substring
/// match). Holds the literal typed text — normalization and matching are
/// [ExpenseSearchEngine]'s job, not this provider's.
final expenseSearchQueryProvider =
    NotifierProvider<ExpenseSearchQueryController, String>(
      ExpenseSearchQueryController.new,
    );

class ExpenseSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;

  void clear() => state = '';
}

/// [expenseListProvider]'s data with both [expenseFilterProvider] and
/// [expenseSearchQueryProvider] applied — filter first, then search, so a
/// search term always narrows within whatever the active filters already
/// allow. Purely a re-map of data already held by the single live listener;
/// changing the filter, the sort, or the search text never issues another
/// Firestore read.
final filteredExpenseListProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  final filter = ref.watch(expenseFilterProvider);
  final query = ref.watch(expenseSearchQueryProvider);
  final expenses = ref.watch(expenseListProvider);
  return expenses.whenData((list) {
    final filtered = ExpenseFilterEngine.apply(list, filter);
    return ExpenseSearchEngine.apply(filtered, query);
  });
});

/// The last six months' totals, ending at [selectedMonthProvider] — another
/// pure re-map of [expenseListProvider]'s already-loaded data; browsing
/// months, like everywhere else on the dashboard, never triggers another
/// Firestore read.
final monthlySpendingChartProvider =
    Provider<AsyncValue<List<MonthlySpendingPoint>>>((ref) {
      final month = ref.watch(selectedMonthProvider);
      final expenses = ref.watch(expenseListProvider);
      return expenses.whenData(
        (list) => ExpenseChartData.monthlySpending(list, endMonth: month),
      );
    });
