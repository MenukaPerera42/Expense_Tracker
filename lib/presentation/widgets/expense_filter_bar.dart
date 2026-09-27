import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_filter.dart';
import '../providers/expense_providers.dart';
import 'category_selector.dart';

/// A horizontally scrollable row of filter/sort controls for the expense
/// history list. Purely presentational — every tap reads or writes
/// [expenseFilterProvider] via its controller; no filtering logic lives
/// here (see [ExpenseFilterEngine] for that).
class ExpenseFilterBar extends ConsumerWidget {
  const ExpenseFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseFilterProvider);
    final notifier = ref.read(expenseFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SortButton(sort: filter.sort, onChanged: notifier.setSort),
          const SizedBox(width: AppSpacing.small),
          _CategoryChip(
            selected: filter.category,
            onSelected: notifier.setCategory,
          ),
          const SizedBox(width: AppSpacing.small),
          _DateChip(selectedDate: filter.date, onPick: notifier.setDate),
          const SizedBox(width: AppSpacing.small),
          _DateRangeChip(
            selectedRange: filter.dateRange,
            onPick: notifier.setDateRange,
          ),
          const SizedBox(width: AppSpacing.small),
          _MonthChip(selectedMonth: filter.month, onPick: notifier.setMonth),
          if (filter.isActive) ...[
            const SizedBox(width: AppSpacing.small),
            ActionChip(
              avatar: const Icon(Icons.clear, size: 18),
              label: const Text('Clear filters'),
              onPressed: notifier.clear,
            ),
          ],
          // Keeps the last chip clear of the screen edge.
          const SizedBox(width: AppSpacing.small),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final ExpenseSortOption sort;
  final ValueChanged<ExpenseSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExpenseSortOption>(
      tooltip: 'Sort',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in ExpenseSortOption.values)
          PopupMenuItem(value: option, child: Text(option.label)),
      ],
      child: Chip(
        avatar: const Icon(Icons.sort, size: 18),
        label: Text(sort.label),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.selected, required this.onSelected});

  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: selected == null
          ? const Icon(Icons.category_outlined, size: 18)
          : Icon(iconForCategory(selected!), size: 18),
      label: Text(selected?.displayName ?? 'Category'),
      selected: selected != null,
      onPressed: () async {
        // Object? (rather than ExpenseCategory?) so a barrier dismiss —
        // which always resolves to null — can be told apart from an
        // explicit "Clear category filter" tap (which resolves to
        // _clearCategory below): dismissing without choosing leaves the
        // current filter untouched instead of silently clearing it.
        final result = await showModalBottomSheet<Object?>(
          context: context,
          builder: (context) => _CategoryPickerSheet(selected: selected),
        );
        if (result == _clearCategory) {
          onSelected(null);
        } else if (result is ExpenseCategory) {
          onSelected(result);
        }
      },
      onDeleted: selected == null ? null : () => onSelected(null),
    );
  }
}

const Object _clearCategory = Object();

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet({required this.selected});

  final ExpenseCategory? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter by category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                for (final category in ExpenseCategory.values)
                  ChoiceChip(
                    avatar: Icon(iconForCategory(category), size: 18),
                    label: Text(category.displayName),
                    selected: category == selected,
                    onSelected: (_) => Navigator.of(context).pop(category),
                  ),
              ],
            ),
            if (selected != null) ...[
              const SizedBox(height: AppSpacing.medium),
              TextButton(
                onPressed: () => Navigator.of(context).pop(_clearCategory),
                child: const Text('Clear category filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.selectedDate, required this.onPick});

  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.event_outlined, size: 18),
      label: Text(
        selectedDate == null
            ? 'Date'
            : DateFormat.yMMMd().format(selectedDate!.toLocal()),
      ),
      selected: selectedDate != null,
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
        );
        if (picked != null) onPick(picked);
      },
      onDeleted: selectedDate == null ? null : () => onPick(null),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  const _DateRangeChip({required this.selectedRange, required this.onPick});

  final DateRange? selectedRange;
  final ValueChanged<DateRange?> onPick;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.date_range_outlined, size: 18),
      label: Text(
        selectedRange == null
            ? 'Date range'
            : '${DateFormat.MMMd().format(selectedRange!.start)} – '
                  '${DateFormat.MMMd().format(selectedRange!.end)}',
      ),
      selected: selectedRange != null,
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: selectedRange == null
              ? null
              : DateTimeRange(
                  start: selectedRange!.start,
                  end: selectedRange!.end,
                ),
          firstDate: DateTime(now.year - 5),
          lastDate: now,
        );
        if (picked != null) {
          onPick(DateRange(start: picked.start, end: picked.end));
        }
      },
      onDeleted: selectedRange == null ? null : () => onPick(null),
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({required this.selectedMonth, required this.onPick});

  final DateTime? selectedMonth;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: const Icon(Icons.calendar_view_month_outlined, size: 18),
      label: Text(
        selectedMonth == null
            ? 'Month'
            : DateFormat.yMMM().format(selectedMonth!),
      ),
      selected: selectedMonth != null,
      onPressed: () async {
        // No dedicated month-only picker in Flutter; a regular date picker
        // in "year" mode lets the user land on the right month quickly, and
        // only the year/month of whatever they confirm is actually used.
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedMonth ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDatePickerMode: DatePickerMode.year,
        );
        if (picked != null) onPick(picked);
      },
      onDeleted: selectedMonth == null ? null : () => onPick(null),
    );
  }
}
