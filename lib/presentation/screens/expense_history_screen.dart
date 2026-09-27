import 'package:flutter/material.dart';

import 'expense_history_view.dart';

/// The full, all-time expense history, reached from the dashboard's
/// "View all" action. `ExpenseHistoryView` itself is unchanged — it was
/// Home's whole body before the dashboard module and is now reused as-is.
class ExpenseHistoryScreen extends StatelessWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Expense History',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Expanded(child: ExpenseHistoryView()),
          ],
        ),
      ),
    );
  }
}
