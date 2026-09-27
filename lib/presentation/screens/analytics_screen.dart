import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_chart_data.dart';
import '../../domain/usecases/expense_summary.dart';
import '../../domain/usecases/month_navigation.dart';
import '../providers/expense_providers.dart';
import '../widgets/category_selector.dart';
import '../widgets/scrollable_fill.dart';
import '../widgets/status_view.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlyExpenseSummaryProvider);
    final pointsAsync = ref.watch(monthlySpendingChartProvider);

    return summaryAsync.when(
      loading: () => const ScrollableFill(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ScrollableFill(
        child: StatusView(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          message: expenseErrorMessage(e),
          action: FilledButton(
            onPressed: () => ref.invalidate(expenseListProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (summary) =>
          _AnalyticsBody(summary: summary, pointsAsync: pointsAsync),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.summary, required this.pointsAsync});

  final MonthlyExpenseSummary summary;
  final AsyncValue<List<MonthlySpendingPoint>> pointsAsync;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.extraLarge,
      ),
      children: [
        // Page title & month selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Analytics', style: tt.headlineSmall),
            _MonthChip(month: summary.month),
          ],
        ),
        const SizedBox(height: AppSpacing.large),

        // ── Summary totals ─────────────────────────────────────────────
        _SummaryRow(summary: summary),
        const SizedBox(height: AppSpacing.large),

        // ── 6-month trend line chart ───────────────────────────────────
        _SectionLabel(title: 'Spending Trend', subtitle: 'Last 6 months'),
        const SizedBox(height: AppSpacing.small),
        _TrendCard(pointsAsync: pointsAsync),
        const SizedBox(height: AppSpacing.large),

        // ── Category breakdown ─────────────────────────────────────────
        if (!summary.isEmpty) ...[
          _SectionLabel(
            title: 'Spending by Category',
            subtitle: '${summary.transactionCount} transactions',
          ),
          const SizedBox(height: AppSpacing.small),
          ...ExpenseChartData.categorySlices(summary.categoryTotals).map(
            (slice) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryBreakdownRow(slice: slice, total: summary.total),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.extraLarge,
            ),
            child: StatusView(
              icon: Icons.bar_chart_outlined,
              title: 'No data yet',
              message: 'Add expenses to see your analytics.',
            ),
          ),
      ],
    );
  }
}

// ─── Summary totals row ───────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final MonthlyExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    double topAmount = 0;
    ExpenseCategory? topCat;
    for (final e in summary.categoryTotals.entries) {
      if (e.value > topAmount) {
        topAmount = e.value;
        topCat = e.key;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _InfoTile(
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF1976D2),
            label: 'Total Spent',
            value: CurrencyConfig.defaultCurrency.format(summary.total),
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: _InfoTile(
            icon: Icons.category_rounded,
            iconColor: const Color(0xFF0288D1),
            label: 'Top Category',
            value: topCat?.displayName ?? '—',
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 6-month line chart card ─────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.pointsAsync});
  final AsyncValue<List<MonthlySpendingPoint>> pointsAsync;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: pointsAsync.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox(
          height: 160,
          child: Center(child: Icon(Icons.error_outline)),
        ),
        data: (points) {
          if (points.isEmpty || points.every((p) => p.total <= 0)) {
            return SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No spending data yet',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }

          final maxVal = points
              .map((p) => p.total)
              .reduce((a, b) => a > b ? a : b);
          final maxY = maxVal > 0 ? maxVal * 1.25 : 1.0;

          final spots = points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.total))
              .toList();

          return SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: -maxVal * 0.05,
                maxY: maxY,
                clipData: const FlClipData.none(),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withOpacity(0.3),
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
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            DateFormat.MMM().format(points[i].month),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => cs.inverseSurface,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            CurrencyConfig.defaultCurrency.format(s.y),
                            tt.labelSmall!.copyWith(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.4,
                    color: cs.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: cs.primary,
                        strokeColor: cs.surface,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withOpacity(0.20),
                          cs.primary.withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Category breakdown row ───────────────────────────────────────────────────

class _CategoryBreakdownRow extends StatelessWidget {
  const _CategoryBreakdownRow({required this.slice, required this.total});

  final CategorySlice slice;
  final double total;

  static const _barColors = [
    Color(0xFF1565C0),
    Color(0xFF0288D1),
    Color(0xFF0097A7),
    Color(0xFF00838F),
    Color(0xFF1976D2),
    Color(0xFF039BE5),
    Color(0xFF00ACC1),
    Color(0xFF0277BD),
    Color(0xFF006064),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final barColor = _barColors[slice.category.index % _barColors.length];
    final pct = (slice.percentage * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconForCategory(slice.category),
              color: barColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Name + bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slice.category.displayName,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: slice.percentage,
                    minHeight: 5,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount + pct
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyConfig.defaultCurrency.format(slice.amount),
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$pct%',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.titleMedium),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ─── Month chip ──────────────────────────────────────────────────────────────

class _MonthChip extends ConsumerWidget {
  const _MonthChip({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => ref.read(selectedMonthProvider.notifier).previousMonth(),
          child: Icon(Icons.chevron_left, size: 24, color: cs.primary),
        ),
        const SizedBox(width: 4),
        Text(
          DateFormat.yMMM().format(month),
          style: tt.labelLarge?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: MonthNavigation.isCurrentMonth(month)
              ? null
              : () => ref.read(selectedMonthProvider.notifier).nextMonth(),
          child: Icon(
            Icons.chevron_right,
            size: 24,
            color: MonthNavigation.isCurrentMonth(month)
                ? cs.onSurfaceVariant.withOpacity(0.3)
                : cs.primary,
          ),
        ),
      ],
    );
  }
}
