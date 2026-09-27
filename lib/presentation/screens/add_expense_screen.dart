import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../providers/expense_providers.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/expense_form.dart';

/// Polished single-purpose form for recording a new expense. Field layout
/// and validation live in [ExpenseForm]; this screen only owns saving state,
/// success/error feedback, and the unsaved-changes guard.
///
/// Uses plain [Navigator.pop] rather than go_router's `context.pop()` — it
/// only ever needs to return to whichever screen pushed it, which Navigator
/// already handles regardless of how that push happened.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  bool _dirty = false;
  bool _discardConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addExpenseControllerProvider);
    final saving = state.isLoading;

    ref.listen<AsyncValue<void>>(addExpenseControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense saved.')));
        Navigator.of(context).pop();
      } else if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(expenseErrorMessage(next.error))),
        );
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
      child: Scaffold(
        appBar: AppBar(title: const Text('Add expense')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: ExpenseForm(
              initialTitle: '',
              initialAmount: '',
              initialCategory: null,
              initialDate: DateTime.now(),
              initialNote: '',
              saving: saving,
              submitLabel: 'Save expense',
              onDirtyChanged: (dirty) => setState(() => _dirty = dirty),
              onSubmit:
                  ({
                    required title,
                    required amount,
                    required category,
                    required date,
                    required note,
                  }) {
                    ref
                        .read(addExpenseControllerProvider.notifier)
                        .submit(
                          title: title,
                          amount: amount,
                          category: category,
                          date: date,
                          note: note,
                        );
                  },
            ),
          ),
        ),
      ),
    );
  }
}
