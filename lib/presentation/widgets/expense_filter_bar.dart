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
          PopupMenuItem(
            value: option,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: option == sort ? const Color(0xFF0D47A1) : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  color: option == sort
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: option == sort
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
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
    return _HistoryFilterChip(
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
      clearLabel: 'Clear category filter',
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
      child: SingleChildScrollView(
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
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in ExpenseCategory.values)
                  CategoryPill(
                    category: category,
                    isSelected: category == selected,
                    onTap: () => Navigator.of(context).pop(category),
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
    return _HistoryFilterChip(
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
      clearLabel: 'Clear date filter',
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
    return _HistoryFilterChip(
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
      clearLabel: 'Clear date range filter',
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
    return _HistoryFilterChip(
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
      clearLabel: 'Clear month filter',
      onDeleted: selectedMonth == null ? null : () => onPick(null),
    );
  }
}

/// Mirrors the Add Expense category pill palette while retaining chip clearing
/// and built-in keyboard/selection semantics for applied history filters.
class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.avatar,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.onDeleted,
    required this.clearLabel,
  });
  final Widget avatar;
  final Widget label;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback? onDeleted;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const active = Color(0xFF0D47A1);
    final foreground = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return InputChip(
      avatar: avatar,
      label: label,
      selected: selected,
      showCheckmark: false,
      selectedColor: active,
      backgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
      side: BorderSide(
        width: 1.5,
        color: selected
            ? active
            : dark
            ? const Color(0xFF334155)
            : const Color(0xFFCBD5E1),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: TextStyle(
        fontSize: 13,
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      iconTheme: IconThemeData(color: foreground, size: 18),
      deleteIconColor: foreground,
      deleteButtonTooltipMessage: clearLabel,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      onPressed: onPressed,
      onDeleted: onDeleted,
    );
  }
}
