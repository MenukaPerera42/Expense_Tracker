import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_validation.dart';
import 'category_selector.dart';
import 'date_field.dart';

/// Validated primitive values a submitted [ExpenseForm] hands back to its
/// owner. Building an [Expense] and persisting it differ between creating
/// (AddExpenseController) and updating (EditExpenseController), so this
/// widget only ever deals in strings/values, never Firestore or the entity.
typedef ExpenseFormSubmit = void Function({
  required String title,
  required String amount,
  required ExpenseCategory category,
  required DateTime date,
  required String note,
});

/// The Add/Edit expense form: title, amount, category, date, optional note.
/// Shared by AddExpenseScreen and the expense editor so the fields,
/// validation and "no future dates" product rule live in exactly one place.
class ExpenseForm extends StatefulWidget {
  const ExpenseForm({
    super.key,
    required this.initialTitle,
    required this.initialAmount,
    required this.initialCategory,
    required this.initialDate,
    required this.initialNote,
    required this.saving,
    required this.submitLabel,
    required this.onSubmit,
    this.onDirtyChanged,
  });

  final String initialTitle;
  final String initialAmount;
  final ExpenseCategory? initialCategory;
  final DateTime initialDate;
  final String initialNote;
  final bool saving;
  final String submitLabel;
  final ExpenseFormSubmit onSubmit;

  /// Called whenever any field's current value starts or stops matching its
  /// initial value, so the owning screen can guard against navigating away
  /// with unsaved changes.
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<ExpenseForm> createState() => ExpenseFormState();
}

class ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late ExpenseCategory? _category;
  late DateTime _date;
  bool _categoryTouched = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle)
      ..addListener(_notifyDirty);
    _amountController = TextEditingController(text: widget.initialAmount)
      ..addListener(_notifyDirty);
    _noteController = TextEditingController(text: widget.initialNote)
      ..addListener(_notifyDirty);
    _category = widget.initialCategory;
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // A simple, string/value-level comparison against the initial values.
  // Practical rather than perfect: retyping the same amount in a different
  // textual form (e.g. "24.0" for an initial "24") reads as dirty even
  // though it parses to the same number.
  bool get _isDirty =>
      _titleController.text != widget.initialTitle ||
      _amountController.text != widget.initialAmount ||
      _category != widget.initialCategory ||
      _date != widget.initialDate ||
      _noteController.text != widget.initialNote;

  void _notifyDirty() => widget.onDirtyChanged?.call(_isDirty);

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
    if (picked != null) {
      setState(() => _date = picked);
      _notifyDirty();
    }
  }

  void _submit() {
    if (widget.saving) return;
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
    widget.onSubmit(
      title: _titleController.text,
      amount: _amountController.text,
      category: _category!,
      date: _date,
      note: _noteController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final saving = widget.saving;
    return Form(
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                : (category) {
                    setState(() {
                      _category = category;
                      _categoryTouched = true;
                    });
                    _notifyDirty();
                  },
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
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
