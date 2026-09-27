import 'package:flutter/material.dart';

import '../../domain/entities/expense.dart';
import '../widgets/status_view.dart';

/// Navigation target for the history list's edit action. Editing itself
/// (a reusable form shared with Add Expense, plus its own save/validation
/// tests) is the next module; this placeholder confirms the right expense
/// was reached and gives the user an honest status instead of a dead end.
class EditExpenseScreen extends StatelessWidget {
  const EditExpenseScreen({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit expense')),
      body: SafeArea(
        child: StatusView(
          icon: Icons.edit_note_outlined,
          title: 'Editing is coming next',
          message:
              'Updating "${expense.title}" will be available in the next '
              'module. For now, delete it from Expense history and add it '
              'again with the correct details.',
        ),
      ),
    );
  }
}
