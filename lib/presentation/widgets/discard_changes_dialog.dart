import 'package:flutter/material.dart';

/// Shared "are you sure" prompt for leaving a form with unsaved changes.
/// Returns true if the user chose to discard, false if they chose to keep
/// editing (or dismissed the dialog without choosing).
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text(
        "You have unsaved changes. If you leave now, they'll be lost.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result ?? false;
}
