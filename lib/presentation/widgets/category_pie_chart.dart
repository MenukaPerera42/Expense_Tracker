import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/usecases/expense_chart_data.dart';
import 'category_selector.dart';

/// A compact donut chart of category spending shares. Deliberately small
/// and unobtrusive — a fixed, modest height rather than filling the
/// screen — since [CategorySummaryList] underneath already carries the
/// exact figures and category names; this chart's only job is to make
/// relative proportions easy to see at a glance.
///
/// Takes pre-computed [CategorySlice]s (see `domain/usecases/expense_chart_data.dart`)
/// rather than a repository, a provider, or a raw expense list, so it has no
/// path to Firestore and can be reused or previewed with any data.
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.slices});

  final List<CategorySlice> slices;

  /// Slices below this share aren't worth a percentage label inside the
  /// (small) chart — it would either be unreadable or crowd its neighbors.
  /// The exact figure is always available in the legend list below.
  static const _minLabeledShare = 0.08;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (slices.isEmpty) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Text(
            'No spending yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keeps the donut a fixed, modest size on any width rather than
        // stretching edge-to-edge on a tablet — chart stays a supporting
        // element, not the dominant one on the screen.
        final diameter = constraints.maxWidth.clamp(0, 320).toDouble();
        return SizedBox(
          height: 160,
          child: Center(
            child: SizedBox(
              width: diameter,
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.amount <= 0 ? 0.0001 : slice.amount,
                        color: colorForCategory(slice.category),
                        radius: 44,
                        title: slice.percentage >= _minLabeledShare
                            ? '${(slice.percentage * 100).round()}%'
                            : '',
                        titleStyle: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                  sectionsSpace: slices.length > 1 ? 2 : 0,
                  centerSpaceRadius: 32,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
