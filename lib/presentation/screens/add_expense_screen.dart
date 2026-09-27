import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/config/currency_config.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_validation.dart';
import '../providers/expense_providers.dart';
import '../widgets/category_selector.dart';
import '../widgets/date_field.dart';

/// Polished single-purpose form for recording a new expense. Validation and
/// persistence are delegated (ExpenseValidation, AddExpenseController); this
/// widget only owns transient form state and presentation.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  ExpenseCategory? _category;
  DateTime _date = DateTime.now();
  bool _categoryTouched = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 10),
      // Product rule: expenses cannot be dated in the future (see
      // ExpenseValidation.date). Constraining lastDate keeps the picker
      // from ever offering an invalid choice in the first place.
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (ref.read(addExpenseControllerProvider).isLoading) return;
    setState(() => _categoryTouched = true);
    final formValid = _formKey.currentState!.validate();
    final dateValid = ExpenseValidation.date(_date) == null;
    if (!formValid || _category == null || !dateValid) {
      if (!dateValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Date cannot be in the future.')),
        );
      }
      return;
    }
    FocusScope.of(context).unfocus();
    ref
        .read(addExpenseControllerProvider.notifier)
        .submit(
          title: _titleController.text,
          amount: _amountController.text,
          category: _category!,
          date: _date,
          note: _noteController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addExpenseControllerProvider);
    final saving = state.isLoading;

    ref.listen<AsyncValue<void>>(addExpenseControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.isLoading == true && next.hasValue && !next.isLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Expense saved.')));
        context.pop();
      } else if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(expenseErrorMessage(next.error))));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Add expense')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: ExpenseValidation.titleMaxLength,
                  validator: ExpenseValidation.title,
                ),
                const SizedBox(height: AppSpacing.small),
                TextFormField(
                  controller: _amountController,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '${CurrencyConfig.defaultCurrency.code} ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  textInputAction: TextInputAction.next,
                  validator: ExpenseValidation.amount,
                ),
                const SizedBox(height: AppSpacing.medium),
                CategorySelector(
                  selected: _category,
                  onChanged: saving
                      ? null
                      : (category) => setState(() {
                          _category = category;
                          _categoryTouched = true;
                        }),
                  errorText: _categoryTouched && _category == null
                      ? 'Choose a category.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.medium),
                DateField(date: _date, enabled: !saving, onTap: _pickDate),
                const SizedBox(height: AppSpacing.medium),
                TextFormField(
                  controller: _noteController,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Note (optional)'),
                  maxLength: ExpenseValidation.noteMaxLength,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                  validator: ExpenseValidation.note,
                ),
                const SizedBox(height: AppSpacing.medium),
                FilledButton(
                  onPressed: saving ? null : _submit,
                  child: saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Please wait',
                          ),
                        )
                      : const Text('Save expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
