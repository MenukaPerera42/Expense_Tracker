import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../../routing/close_expense_screen.dart';
import '../providers/expense_providers.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/expense_form.dart';

/// Polished single-purpose form for recording a new expense. Field layout
/// and validation live in [ExpenseForm]; this screen only owns saving state,
/// success/error feedback, and the unsaved-changes guard.
///
/// Returns to the caller, or home when opened directly.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  bool _dirty = false;
  bool _discardConfirmed = false;
  bool _confirmingDiscard = false;

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
        closeExpenseScreen(context);
      } else if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(expenseErrorMessage(next.error))),
        );
      }
    });

    return PopScope(
      canPop: !_dirty || _discardConfirmed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _confirmingDiscard) return;
        _confirmingDiscard = true;
        // A blocked pop may be reported while Navigator is still locked.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final discard = await confirmDiscardChanges(context);
          if (!mounted) return;
          _confirmingDiscard = false;
          if (!discard) return;
          setState(() => _discardConfirmed = true);
          // Let PopScope register canPop before attempting navigation again.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) closeExpenseScreen(context);
          });
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.extraLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Expense',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.large),
                ExpenseForm(
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
                // Closing bracket for children of Column
              ],
            ),
          ),
        ),
      ),
    );
  }
}
