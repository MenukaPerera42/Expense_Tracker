import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';

/// Representative icon per category. Presentation-only association: the
/// domain entity itself stores no icon or color (see domain/README.md).
const Map<ExpenseCategory, IconData> _categoryIcons = {
  ExpenseCategory.food: Icons.restaurant_outlined,
  ExpenseCategory.transport: Icons.directions_bus_outlined,
  ExpenseCategory.shopping: Icons.shopping_bag_outlined,
  ExpenseCategory.bills: Icons.receipt_long_outlined,
  ExpenseCategory.entertainment: Icons.movie_outlined,
  ExpenseCategory.health: Icons.favorite_outline,
  ExpenseCategory.education: Icons.school_outlined,
  ExpenseCategory.travel: Icons.flight_takeoff_outlined,
  ExpenseCategory.other: Icons.category_outlined,
};

IconData iconForCategory(ExpenseCategory category) => _categoryIcons[category]!;

/// A visually clear, single-select category picker built from chips rather
/// than a dropdown, so all nine categories and their icons are visible and
/// reachable in one tap.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.errorText,
  });

  final ExpenseCategory? selected;
  final ValueChanged<ExpenseCategory>? onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.labelLarge?.copyWith(
            color: hasError ? theme.colorScheme.error : null,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            for (final category in ExpenseCategory.values)
              ChoiceChip(
                avatar: Icon(iconForCategory(category), size: 18),
                label: Text(category.displayName),
                selected: category == selected,
                onSelected: onChanged == null
                    ? null
                    : (_) => onChanged!(category),
              ),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.small),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
