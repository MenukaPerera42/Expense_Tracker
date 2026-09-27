import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/usecases/month_navigation.dart';
import '../providers/expense_providers.dart';

class MonthSelector extends ConsumerWidget {
  const MonthSelector({super.key, required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: () =>
            ref.read(selectedMonthProvider.notifier).previousMonth(),
        icon: const Icon(Icons.chevron_left, size: 20),
      ),
      Flexible(
        child: Text(
          DateFormat.yMMM().format(month),
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
      IconButton(
        tooltip: 'Next month',
        onPressed: MonthNavigation.isCurrentMonth(month)
            ? null
            : () => ref.read(selectedMonthProvider.notifier).nextMonth(),
        icon: const Icon(Icons.chevron_right, size: 20),
      ),
    ],
  );
}
