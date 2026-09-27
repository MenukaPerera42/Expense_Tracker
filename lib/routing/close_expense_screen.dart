import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Return to the caller, or home when the form was opened via a direct URL.
void closeExpenseScreen(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    GoRouter.of(context).go('/');
  }
}
