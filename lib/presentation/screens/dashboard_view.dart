import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/currency_config.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/greeting.dart';
import '../../domain/usecases/expense_chart_data.dart';
import '../../domain/usecases/expense_summary.dart';
import '../../domain/usecases/month_navigation.dart';
import '../../routing/app_router.dart';
import '../providers/auth_providers.dart';
import '../providers/expense_providers.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/category_summary_list.dart';
import '../widgets/expense_list_item.dart';
import '../widgets/monthly_spending_chart.dart';
import '../widgets/status_view.dart';

/// Home's body: current-month spending at a glance, with the ability to
/// browse earlier months. Everything shown here — the total, the category
/// breakdown, the recent list — is aggregated client-side from the single
/// live [expenseListProvider] listener via [monthlyExpenseSummaryProvider],
/// so navigating between months never issues another Firestore read.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlyExpenseSummaryProvider);
    final month = ref.watch(selectedMonthProvider);
    final userName = ref.watch(authStateProvider).valueOrNull?.name;

    return RefreshIndicator(
      // The one user-triggered action that re-subscribes to Firestore.
      // Switching months (below) never does this.
      onRefresh: () => ref.refresh(expenseListProvider.future),
      child: summaryAsync.when(
        loading: () => const _ScrollableFill(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => _ScrollableFill(
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
        data: (summary) => _DashboardContent(summary: summary, userName: userName),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.summary, required this.userName});

  final MonthlyExpenseSummary summary;
  final String? userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final greeting = greetingForHour(DateTime.now().hour);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.medium,
        AppSpacing.medium,
        // Extra bottom padding keeps the last card clear of the FAB.
        AppSpacing.extraLarge * 2,
      ),
      children: [
        Text(
          userName == null || userName!.trim().isEmpty
              ? greeting
              : '$greeting, ${userName!.trim()}',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.large),
        const _MonthSelector(),
        const SizedBox(height: AppSpacing.medium),
        _TotalSpendingCard(summary: summary),
        const SizedBox(height: AppSpacing.large),
        Text('Last 6 months', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.medium),
        const _MonthlyTrendChart(),
        const SizedBox(height: AppSpacing.large),
        if (summary.isEmpty)
          _EmptyMonth(month: summary.month)
        else ...[
          Text('Spending by category', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.medium),
          CategoryPieChart(
            slices: ExpenseChartData.categorySlices(summary.categoryTotals),
          ),
          const SizedBox(height: AppSpacing.medium),
          CategorySummaryList(
            categoryTotals: summary.categoryTotals,
            total: summary.total,
          ),
          const SizedBox(height: AppSpacing.large),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent expenses', style: theme.textTheme.titleMedium),
              TextButton(
                onPressed: () => context.push(AppRouter.expenseHistoryPath),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          for (final expense in summary.recentExpenses)
            Padding(
              key: ValueKey(expense.id),
              padding: const EdgeInsets.only(bottom: AppSpacing.small),
              child: ExpenseListItem(
                expense: expense,
                onEdit: () =>
                    context.push(AppRouter.editExpensePath(expense.id)),
              ),
            ),
        ],
      ],
    );
  }
}

/// Shown regardless of whether the *selected* month is empty — a trend
/// chart's value is in the months around an empty one, not just in it.
class _MonthlyTrendChart extends ConsumerWidget {
  const _MonthlyTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(monthlySpendingChartProvider);
    return pointsAsync.when(
      loading: () => const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (points) => MonthlySpendingChart(points: points),
    );
  }
}

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final isCurrentMonth = MonthNavigation.isCurrentMonth(month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: () =>
              ref.read(selectedMonthProvider.notifier).previousMonth(),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          DateFormat.yMMMM().format(month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          tooltip: 'Next month',
          // Disabled rather than silently capped, so it's clear there is no
          // later month to move to yet.
          onPressed: isCurrentMonth
              ? null
              : () => ref.read(selectedMonthProvider.notifier).nextMonth(),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TotalSpendingCard extends StatelessWidget {
  const _TotalSpendingCard({required this.summary});

  final MonthlyExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total spending',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              CurrencyConfig.defaultCurrency.format(summary.total),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              summary.transactionCount == 1
                  ? '1 transaction'
                  : '${summary.transactionCount} transactions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month});

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

/// Keeps loading/error content usable with [RefreshIndicator], which
/// requires a scrollable descendant to detect the pull gesture.
class _ScrollableFill extends StatelessWidget {
  const _ScrollableFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ],
      ),
    );
  }
}
