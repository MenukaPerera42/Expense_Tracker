import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../routing/app_router.dart';
import '../providers/expense_providers.dart';
import '../widgets/expense_list_item.dart';
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

    final expenses = ref.watch(expenseListProvider);
    return expenses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatusView(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: expenseErrorMessage(error),
        action: FilledButton(
          onPressed: () => ref.invalidate(expenseListProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (expenses) {
        if (expenses.isEmpty) {
          return StatusView(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses yet',
            message: 'Add your first expense to start tracking your spending.',
            action: FilledButton.icon(
              onPressed: () => context.push(AppRouter.addExpensePath),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          );
        }
        return ListView.builder(
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
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: ExpenseListItem(
                expense: expense,
                onEdit: () =>
                    context.push(AppRouter.editExpensePath(expense.id)),
              ),
            );
          },
        );
      },
    );
  }
}
