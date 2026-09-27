/// Form-level validation for the expense editor. These are UI-facing policy
/// choices (max lengths, "no future dates"), distinct from the [Expense]
/// entity's own structural invariants (non-blank title, finite positive
/// amount, consistent timestamps) enforced in the domain layer.
abstract final class ExpenseValidation {
  /// Generous enough for any real expense title, short enough to keep list
  /// rows and cards from wrapping awkwardly.
  static const titleMaxLength = 120;

  /// Optional free-text note; long enough for context, short enough to
  /// discourage pasting entire receipts.
  static const noteMaxLength = 300;

  /// Guards against fat-finger entry (e.g. an extra digit) rather than
  /// representing any real currency limit.
  static const maxAmount = 999999999.99;

  static String? title(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Enter a title.';
    if (title.length > titleMaxLength) {
      return 'Use at most $titleMaxLength characters.';
    }
    return null;
  }

  /// Accepts plain decimal input (a leading '-' is rejected explicitly so the
  /// message reads "must be greater than zero" instead of "not a number").
  static String? amount(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter an amount.';
    final parsed = double.tryParse(text);
    if (parsed == null || !parsed.isFinite) {
      return 'Enter a valid number.';
    }
    if (parsed <= 0) return 'Amount must be greater than zero.';
    if (parsed > maxAmount) return 'Amount is too large.';
    return null;
  }

  static String? note(String? value) {
    final note = value?.trim() ?? '';
    if (note.length > noteMaxLength) {
      return 'Use at most $noteMaxLength characters.';
    }
    return null;
  }

  /// Product rule: an expense records money already spent, so its date must
  /// not be in the future. The date picker also constrains its `lastDate` to
  /// today so the picker never offers an invalid choice; this validator is
  /// the defensive second check for any date that reaches submission by
  /// another path.
  static String? date(DateTime value, {DateTime? now}) {
    if (value.isAfter(now ?? DateTime.now())) {
      return 'Date cannot be in the future.';
    }
    return null;
  }
}
