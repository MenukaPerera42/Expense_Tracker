import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../routing/app_router.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_filter_bar.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/expense_list_skeleton.dart';
import '../widgets/expense_search_field.dart';
import '../widgets/scrollable_fill.dart';
import '../widgets/status_view.dart';

/// The main workspace content: the signed-in user's expense history, newest
/// first. Owns the loading/empty/error/loaded states for [expenseListProvider]
/// and the shared success/error feedback for deletes, so [ExpenseListItem]
/// stays purely presentational and safe to remove mid-delete once the
/// underlying stream updates.
class ExpenseHistoryView extends ConsumerWidget {
  const ExpenseHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<Map<String, AsyncValue<void>>>(deleteExpenseControllerProvider, (
      previous,
      next,
    ) {
      for (final entry in next.entries) {
        final before = previous?[entry.key];
        if (before?.isLoading == true &&
            entry.value.hasValue &&
            !entry.value.isLoading) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Expense deleted.')));
          ref.read(deleteExpenseControllerProvider.notifier).clear(entry.key);
        } else if (entry.value.hasError &&
            !(before?.hasError ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(expenseErrorMessage(entry.value.error))),
          );
          ref.read(deleteExpenseControllerProvider.notifier).clear(entry.key);
        }
      }
    });

    // The raw (unfiltered) list decides whether there are any expenses at
    // all; filteredExpenseListProvider re-maps the same data through the
    // active ExpenseFilter, so switching filters never re-queries Firestore.
    final hasAnyExpenses = ref.watch(
      expenseListProvider.select((state) => state.valueOrNull?.isNotEmpty ?? false),
    );
    final filtered = ref.watch(filteredExpenseListProvider);

    return RefreshIndicator(
      // Mirrors the dashboard's pull-to-refresh: the one user-triggered
      // action that re-subscribes to Firestore. Filtering/searching/sorting
      // never do.
      onRefresh: () => ref.refresh(expenseListProvider.future),
      child: filtered.when(
        loading: () => const ExpenseListSkeleton(),
        error: (error, _) => ScrollableFill(
          child: StatusView(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: expenseErrorMessage(error),
            action: FilledButton(
              onPressed: () => ref.invalidate(expenseListProvider),
              child: const Text('Retry'),
            ),
          ),
        ),
        data: (expenses) {
          if (!hasAnyExpenses) {
            return ScrollableFill(
              child: StatusView(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                message:
                    'Add your first expense to start tracking your spending.',
                action: FilledButton.icon(
                  onPressed: () => context.push(AppRouter.addExpensePath),
                  icon: const Icon(Icons.add),
                  label: const Text('Add expense'),
                ),
              ),
            );
          }
          final searchActive = ref.watch(
            expenseSearchQueryProvider.select((query) => query.trim().isNotEmpty),
          );
          final filterActive = ref.watch(
            expenseFilterProvider.select((filter) => filter.isActive),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  AppSpacing.medium,
                  AppSpacing.medium,
                  0,
                ),
                child: Column(
                  children: [
                    const ExpenseSearchField(),
                    const SizedBox(height: AppSpacing.small),
                    const ExpenseFilterBar(),
                  ],
                ),
              ),
              Expanded(
                child: expenses.isEmpty
                    ? ScrollableFill(
                        child: StatusView(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'No matching expenses',
                          message:
                              'Try a different search term, category, date, or range.',
                          action: FilledButton(
                            onPressed: () {
                              if (searchActive) {
                                ref
                                    .read(expenseSearchQueryProvider.notifier)
                                    .clear();
                              }
                              if (filterActive) {
                                ref
                                    .read(expenseFilterProvider.notifier)
                                    .clear();
                              }
                            },
                            child: Text(
                              searchActive && filterActive
                                  ? 'Clear search & filters'
                                  : searchActive
                                  ? 'Clear search'
                                  : 'Clear filters',
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.medium,
                          AppSpacing.medium,
                          AppSpacing.medium,
                          // Extra bottom padding keeps the last card clear of the FAB.
                          AppSpacing.extraLarge * 2,
                        ),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return Padding(
                            key: ValueKey(expense.id),
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.small,
                            ),
                            child: ExpenseListItem(
                              expense: expense,
                              onEdit: () => context.push(
                                AppRouter.editExpensePath(expense.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
