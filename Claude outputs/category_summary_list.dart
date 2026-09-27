import 'package:flutter/material.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import 'category_selector.dart';

/// A per-category breakdown of the selected month's spending: each
/// category's share of the month's total as a proportional bar, sorted
/// highest-spend first. Doubles as the legend for [CategoryPieChart] — same
/// per-category colors, exact figures the pie chart's slices don't have
/// room to print.
class CategorySummaryList extends StatelessWidget {
  const CategorySummaryList({
    super.key,
    required this.categoryTotals,
    required this.total,
  });

  final Map<ExpenseCategory, double> categoryTotals;
  final double total;

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.small),
            child: _CategoryRow(
              category: entry.key,
              amount: entry.value,
              share: total > 0 ? entry.value / total : 0,
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.share,
  });

  final ExpenseCategory category;
  final double amount;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          iconForCategory(category),
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category.displayName,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    CurrencyConfig.defaultCurrency.format(amount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share.clamp(0, 1).toDouble(),
                  minHeight: 6,
                  color: colorForCategory(category),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
