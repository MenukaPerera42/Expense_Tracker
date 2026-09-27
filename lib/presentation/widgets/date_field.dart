import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A tappable field that opens a date picker and displays the chosen date
/// with the app's shared input decoration, so it reads like the surrounding
/// [TextFormField]s despite not being one.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.date,
    required this.onTap,
    this.enabled = true,
    this.errorText,
  });

  final DateTime date;
  final VoidCallback onTap;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }
}
