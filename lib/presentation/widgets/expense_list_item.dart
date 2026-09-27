import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';
import 'category_selector.dart';

/// A single row in the expense history list. Purely presentational plus the
/// delete confirmation dialog; success/error feedback and list updates are
/// handled by the ancestor that owns the Firestore stream and the shared
/// delete controller (see ExpenseHistoryView), so this widget never shows
/// its own SnackBar and can be disposed mid-delete without losing feedback.
class ExpenseListItem extends ConsumerWidget {
  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.onEdit,
  });

  final Expense expense;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // .select scopes rebuilds to just this row when only its own delete
    // state changes, instead of the whole list rebuilding on every delete.
    final deleting = ref.watch(
      deleteExpenseControllerProvider.select(
        (state) => state[expense.id]?.isLoading ?? false,
      ),
    );
    final hasNote = expense.note != null && expense.note!.trim().isNotEmpty;

    return Card(
      child: Opacity(
        opacity: deleting ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(iconForCategory(expense.category)),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            expense.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasNote)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.small,
                              top: 2,
                            ),
                            child: Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                              semanticLabel: 'Has a note',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${expense.category.displayName} · '
                      '${DateFormat.yMMMd().format(expense.date.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyConfig.defaultCurrency.format(expense.amount),
                    style: theme.textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit expense',
                        // A real 44x44 minimum tap target (rather than the
                        // visually-compact default) even though the icon
                        // itself stays small, so two icons fit side by side
                        // without shrinking below a comfortable touch size.
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: deleting ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Delete expense',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: deleting
                            ? null
                            : () => _confirmDelete(context, ref),
                        icon: deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'This will permanently delete "${expense.title}". '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(deleteExpenseControllerProvider.notifier)
          .delete(expense.id);
    }
  }
}
