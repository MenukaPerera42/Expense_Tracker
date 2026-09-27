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
      appBar: AppBar(title: const Text('All expenses')),
      body: const SafeArea(child: ExpenseHistoryView()),
    );
  }
}
