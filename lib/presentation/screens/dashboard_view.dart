import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/usecases/expense_chart_data.dart';
import '../../domain/usecases/expense_summary.dart';
import '../../domain/usecases/month_navigation.dart';
import '../../routing/app_router.dart';
import '../providers/auth_providers.dart';
import '../providers/expense_providers.dart';
import '../widgets/category_selector.dart';
import '../widgets/scrollable_fill.dart';
import '../widgets/status_view.dart';

class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlyExpenseSummaryProvider);
    final userName = ref.watch(authStateProvider).value?.name;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(expenseListProvider.future),
      child: summaryAsync.when(
        loading: () => const ScrollableFill(
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading your spending summary',
            ),
          ),
        ),
        error: (error, _) => ScrollableFill(
          child: StatusView(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: expenseErrorMessage(error),
            action: FilledButton(
              onPressed: () => ref.invalidate(expenseListProvider),
              child: const Text('Retry'),
            ),
          ),
        ),
        data: (summary) =>
            _DashboardBody(summary: summary, userName: userName),
      ),
    );
  }
}

// ─── Main scrollable body ────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary, required this.userName});

  final MonthlyExpenseSummary summary;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final displayName =
        (userName == null || userName!.trim().isEmpty) ? 'there' : userName!.trim();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.medium,
      ),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        _Header(displayName: displayName),
        const SizedBox(height: AppSpacing.large),

        // ── Balance hero card ─────────────────────────────────────────────
        _BalanceCard(summary: summary),
        const SizedBox(height: AppSpacing.large),

        // ── Spending trend line chart ─────────────────────────────────────
        _SectionHeader(
          title: 'Spending Trend',
          trailing: _MonthChip(month: summary.month),
        ),
        const SizedBox(height: AppSpacing.small),
        _SpendingLineChart(),
        const SizedBox(height: AppSpacing.large),

        // ── Category breakdown ────────────────────────────────────────────
        if (!summary.isEmpty) ...[
          _SectionHeader(
            title: 'Spending by category',
            trailing: TextButton(
              onPressed: () => context.push(AppRouter.expenseHistoryPath),
              child: const Text('View all'),
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          ...summary.categoryTotals.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: _CategoryRow(
                category: e.key,
                amount: e.value,
                total: summary.total,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
        ],

        // ── Recent transactions ───────────────────────────────────────────
        _SectionHeader(
          title: 'Recent transactions',
          trailing: TextButton(
            onPressed: () => context.push(AppRouter.expenseHistoryPath),
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        if (summary.isEmpty)
          _EmptyState(month: summary.month)
        else
          ...summary.recentExpenses.map(
            (e) => Padding(
              key: ValueKey(e.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: _TransactionRow(
                expense: e,
                onTap: () => context.push(AppRouter.editExpensePath(e.id)),
              ),
            ),
          ),

        // Space for the floating nav bar
        const SizedBox(height: AppSpacing.extraLarge * 2),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Text(
            displayName[0].toUpperCase(),
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_timeOfDay()}!',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                displayName,
                style: tt.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => ref.read(authActionProvider.notifier).logout(),
          icon: Icon(Icons.logout_rounded, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Morning';
    if (h < 17) return 'Afternoon';
    return 'Evening';
  }
}

// ─── Balance hero card ───────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});
  final MonthlyExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF3F51B5), const Color(0xFF1A237E)]
              : [const Color(0xFF5C6BC0), const Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C6BC0).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat.yMMMM().format(summary.month),
                  style: tt.labelSmall?.copyWith(color: Colors.white70),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            'Total Spending',
            style: tt.bodyMedium?.copyWith(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyConfig.defaultCurrency.format(summary.total),
            style: tt.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          // Divider
          Divider(color: Colors.white.withOpacity(0.15), height: 1),
          const SizedBox(height: AppSpacing.medium),
          // Transactions count
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 16,
                color: Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                summary.transactionCount == 1
                    ? '1 transaction'
                    : '${summary.transactionCount} transactions',
                style: tt.bodySmall?.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              // Quick add button — routes to existing add screen
              GestureDetector(
                onTap: () => context.push(AppRouter.addExpensePath),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: tt.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Spending line chart ──────────────────────────────────────────────────────

class _SpendingLineChart extends ConsumerWidget {
  const _SpendingLineChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pointsAsync = ref.watch(monthlySpendingChartProvider);

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
        error: (_, __) => const SizedBox(height: 0),
        data: (points) {
          if (points.isEmpty || points.every((p) => p.total <= 0)) {
            return SizedBox(
              height: 140,
              child: Center(
                child: Text(
                  'No spending data yet',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }

          final maxVal =
              points.map((p) => p.total).reduce((a, b) => a > b ? a : b);
          final maxY = maxVal > 0 ? maxVal * 1.25 : 1.0;
          final spots = points
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.total))
              .toList();

          return SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
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
                    getTooltipItems: (touchedSpots) => touchedSpots
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


// ─── Category rows ────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.total,
  });

  final ExpenseCategory category;
  final double amount;
  final double total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fraction = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);

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
          // Category icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconForCategory(category),
              color: cs.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Name + progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.displayName, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 5,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
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
                CurrencyConfig.defaultCurrency.format(amount),
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

// ─── Recent transaction row ──────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.expense, required this.onTap});
  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                iconForCategory(expense.category),
                color: cs.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Title + category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${expense.category.displayName} · '
                    '${DateFormat.MMMd().format(expense.date.toLocal())}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              '−${CurrencyConfig.defaultCurrency.format(expense.amount)}',
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: tt.titleMedium),
        if (trailing != null) trailing!,
      ],
    );
  }
}

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
          child: Icon(Icons.chevron_left, size: 20, color: cs.onSurfaceVariant),
        ),
        Text(
          DateFormat.yMMM().format(month),
          style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        GestureDetector(
          onTap: MonthNavigation.isCurrentMonth(month)
              ? null
              : () => ref.read(selectedMonthProvider.notifier).nextMonth(),
          child: Icon(
            Icons.chevron_right,
            size: 20,
            color: MonthNavigation.isCurrentMonth(month)
                ? cs.onSurfaceVariant.withOpacity(0.3)
                : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.extraLarge),
      child: StatusView(
        icon: Icons.receipt_long_outlined,
        title: 'No expenses in ${DateFormat.yMMMM().format(month)}',
        message: 'Nothing recorded for this month yet.',
        action: Builder(
          builder: (context) => FilledButton.icon(
            onPressed: () => context.push(AppRouter.addExpensePath),
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
        ),
      ),
    );
  }
}
