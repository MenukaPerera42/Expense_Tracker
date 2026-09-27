import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/currency_config.dart';
import '../../domain/usecases/expense_chart_data.dart';
import '../../domain/usecases/month_navigation.dart';

/// A compact bar chart of the last several months' totals, ending at the
/// dashboard's selected month (highlighted). Purely a rendering of
/// pre-computed [MonthlySpendingPoint]s — no repository, provider, or
/// Firestore access — so it never needs to know where the totals came from.
///
/// Kept short and unobtrusive (a fixed, modest height) since its job is to
/// show a trend at a glance, not to be the page's focal point.
class MonthlySpendingChart extends StatelessWidget {
  const MonthlySpendingChart({super.key, required this.points});

  final List<MonthlySpendingPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (points.isEmpty || points.every((p) => p.total <= 0)) {
      return SizedBox(
        height: 96,
        child: Center(
          child: Text(
            'No spending in this period yet',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final maxTotal = points.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    // A little headroom above the tallest bar so its top isn't flush with
    // the chart edge; falls back to 1 when every bar would otherwise be 0.
    final maxY = maxTotal > 0 ? maxTotal * 1.2 : 1.0;
    final selectedMonth = points.last.month;

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat.MMM().format(points[index].month),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${DateFormat.yMMM().format(points[group.x.toInt()].month)}\n'
                '${CurrencyConfig.defaultCurrency.format(rod.toY)}',
                theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
          barGroups: [
            for (final (index, point) in points.indexed)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: point.total,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                    color: MonthNavigation.isSameMonth(point.month, selectedMonth)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
