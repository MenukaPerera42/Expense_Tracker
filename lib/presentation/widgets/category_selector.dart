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

/// A fixed, stable color per category for charts and other visual
/// summaries. Deliberately not theme-derived: these are chart accent
/// colors that need to stay distinguishable from each other regardless of
/// the seeded Material color scheme, in both light and dark mode — the
/// `shade400` tone reads clearly against both a light and a dark surface.
const Map<ExpenseCategory, MaterialColor> _categoryColors = {
  ExpenseCategory.food: Colors.orange,
  ExpenseCategory.transport: Colors.blue,
  ExpenseCategory.shopping: Colors.purple,
  ExpenseCategory.bills: Colors.red,
  ExpenseCategory.entertainment: Colors.pink,
  ExpenseCategory.health: Colors.green,
  ExpenseCategory.education: Colors.teal,
  ExpenseCategory.travel: Colors.indigo,
  ExpenseCategory.other: Colors.blueGrey,
};

Color colorForCategory(ExpenseCategory category) =>
    _categoryColors[category]!.shade400;

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
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in ExpenseCategory.values)
              _CategoryPill(
                category: category,
                isSelected: category == selected,
                onTap: onChanged == null ? null : () => onChanged!(category),
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

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final ExpenseCategory category;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = colorForCategory(category);

    // Unselected colors matching the new Apple-style inputs
    final unselectedBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final unselectedBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final unselectedText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? catColor : unselectedBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? catColor : unselectedBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: catColor.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                // Use rounded icons if available, otherwise regular
                iconForCategory(category),
                key: ValueKey(isSelected),
                size: 18,
                color: isSelected ? Colors.white : unselectedText,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : unselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
