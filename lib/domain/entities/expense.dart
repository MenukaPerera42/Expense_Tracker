import 'expense_category.dart';

/// Immutable expense. Dates represent instants, normalized to UTC.
/// Amount is a finite, positive value in the app's configured currency.
final class Expense {
  Expense({
    required this.id,
    required this.userId,
    required this.title,
    required num amount,
    required this.category,
    required DateTime date,
    this.note,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : amount = _amount(amount),
       date = date.toUtc(),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    for (final entry in {'id': id, 'userId': userId}.entries) {
      if (entry.value.trim().isEmpty || entry.value.contains('/')) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Expected a nonempty document identifier',
        );
      }
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be blank');
    }
    for (final value in [this.date, this.createdAt, this.updatedAt]) {
      if (value.year < 1 || value.year > 9999) {
        throw ArgumentError(
          'Dates must be in the Firestore-supported years 1–9999',
        );
      }
    }
    if (updatedAt.isBefore(createdAt)) {
      throw ArgumentError('updatedAt must not precede createdAt');
    }
  }

  final String id;
  final String userId;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  static double _amount(num value) {
    final converted = value.toDouble();
    if (!converted.isFinite ||
        converted <= 0 ||
        (value is int && value > 9007199254740991)) {
      throw ArgumentError.value(
        value,
        'amount',
        'Must be positive, finite and representable without integer precision loss',
      );
    }
    return converted;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          id == other.id &&
          userId == other.userId &&
          title == other.title &&
          amount == other.amount &&
          category == other.category &&
          date == other.date &&
          note == other.note &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    title,
    amount,
    category,
    date,
    note,
    createdAt,
    updatedAt,
  );
}
