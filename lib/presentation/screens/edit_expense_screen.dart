import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/expense_form.dart';
import '../widgets/status_view.dart';

/// Loads an existing expense by ID and lets the user edit it, reusing
/// [ExpenseForm]. The ID always comes from the route (not from whatever the
/// caller happened to have in hand), so this screen fetches fresh and can
/// genuinely detect "this was deleted since the list loaded" rather than
/// trusting stale data passed along with the navigation.
///
/// Uses plain [Navigator.pop] rather than go_router's `context.pop()` — it
/// only ever needs to return to whichever screen pushed it.
class EditExpenseScreen extends ConsumerWidget {
  const EditExpenseScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseAsync = ref.watch(expenseByIdProvider(expenseId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit expense')),
      body: SafeArea(
        child: expenseAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading expense',
            ),
          ),
          error: (error, _) => StatusView(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: expenseErrorMessage(error),
            action: FilledButton(
              onPressed: () => ref.invalidate(expenseByIdProvider(expenseId)),
              child: const Text('Retry'),
            ),
          ),
          data: (expense) {
            if (expense == null) {
              return StatusView(
                icon: Icons.search_off_outlined,
                title: 'Expense not found',
                message: 'This expense may have already been deleted.',
                action: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go back'),
                ),
              );
            }
            return EditExpenseFormView(expense: expense);
          },
        ),
      ),
    );
  }
}

/// The save lifecycle for an already-loaded expense: populates [ExpenseForm]
/// with its current values, preserves its ID/owner/createdAt (see
/// [EditExpenseController]), and guards against navigating away with
/// unsaved changes.
class EditExpenseFormView extends ConsumerStatefulWidget {
  const EditExpenseFormView({super.key, required this.expense});

  final Expense expense;

  @override
  ConsumerState<EditExpenseFormView> createState() =>
      _EditExpenseFormViewState();
}

class _EditExpenseFormViewState extends ConsumerState<EditExpenseFormView> {
  bool _dirty = false;
  bool _discardConfirmed = false;

  /// Plain decimal text for the amount field — not currency-formatted —
  /// since it must round-trip through ExpenseValidation.amount unchanged.
  String get _initialAmount {
    final amount = widget.expense.amount;
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editExpenseControllerProvider);
    final saving = state.isLoading;

    ref.listen<AsyncValue<void>>(editExpenseControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Changes saved.')));
        Navigator.of(context).pop();
      } else if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(expenseErrorMessage(next.error))));
      }
    });

    return PopScope(
      canPop: !_dirty || _discardConfirmed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await confirmDiscardChanges(context);
        if (discard && context.mounted) {
          setState(() => _discardConfirmed = true);
          Navigator.of(context).pop();
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: ExpenseForm(
          initialTitle: widget.expense.title,
          initialAmount: _initialAmount,
          initialCategory: widget.expense.category,
          initialDate: widget.expense.date,
          initialNote: widget.expense.note ?? '',
          saving: saving,
          submitLabel: 'Save changes',
          onDirtyChanged: (dirty) => setState(() => _dirty = dirty),
          onSubmit: ({
            required title,
            required amount,
            required category,
            required date,
            required note,
          }) {
            ref
                .read(editExpenseControllerProvider.notifier)
                .submit(
                  original: widget.expense,
                  title: title,
                  amount: amount,
                  category: category,
                  date: date,
                  note: note,
                );
          },
        ),
      ),
    );
  }
}
