import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

/// JSON uses ISO-8601 strings; Firestore uses Timestamp. The domain knows neither.
abstract final class ExpenseMapper {
  static Map<String, dynamic> toJson(Expense expense) => {
    'id': expense.id,
    'userId': expense.userId,
    'title': expense.title,
    'amount': expense.amount,
    'category': expense.category.code,
    'date': expense.date.toIso8601String(),
    'note': expense.note,
    'createdAt': expense.createdAt.toIso8601String(),
    'updatedAt': expense.updatedAt.toIso8601String(),
  };

  static Expense fromJson(Map<String, dynamic> json) => _read(json, _jsonDate);

  /// Document ID is authoritative; it is not duplicated in the stored payload.
  static Map<String, dynamic> toFirestore(Expense expense) => {
    ...toJson(expense)..remove('id'),
    'date': Timestamp.fromDate(expense.date),
    'createdAt': Timestamp.fromDate(expense.createdAt),
    'updatedAt': Timestamp.fromDate(expense.updatedAt),
  };

  static Expense fromFirestore(
    Map<String, dynamic> data, {
    required String documentId,
  }) {
    if (data.containsKey('id') && data['id'] != documentId) {
      throw const FormatException(
        'Stored expense ID does not match document ID',
      );
    }
    return _read({...data, 'id': documentId}, _firestoreDate);
  }

  static Expense _read(
    Map<String, dynamic> data,
    DateTime Function(Object?, String) dateReader,
  ) {
    final amount = data['amount'];
    if (amount is! num) throw const FormatException('amount must be a number');
    final note = data['note'];
    if (note != null && note is! String) {
      throw const FormatException('note must be a string or null');
    }
    try {
      return Expense(
        id: _string(data, 'id'),
        userId: _string(data, 'userId'),
        title: _string(data, 'title'),
        amount: amount,
        category: ExpenseCategory.fromCode(_string(data, 'category')),
        date: dateReader(data['date'], 'date'),
        note: note as String?,
        createdAt: dateReader(data['createdAt'], 'createdAt'),
        updatedAt: dateReader(data['updatedAt'], 'updatedAt'),
      );
    } on ArgumentError {
      throw const FormatException('Expense contains invalid field values');
    }
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String) throw FormatException('$key must be a string');
    return value;
  }

  static DateTime _firestoreDate(Object? value, String key) {
    if (value is! Timestamp) {
      throw FormatException('$key must be a Firestore Timestamp');
    }
    return value.toDate().toUtc();
  }

  static DateTime _jsonDate(Object? value, String key) {
    if (value is! String) {
      throw FormatException('$key must be an ISO-8601 string');
    }
    // Require a timezone, reject rollover dates and excess precision rather than
    // accepting DateTime.parse's normalization of e.g. February 30.
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('$key must include a timezone and time');
    }
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final normalized = DateTime.utc(parts[0], parts[1], parts[2]);
    final zone = match.group(7)!;
    if (normalized.year != parts[0] ||
        normalized.month != parts[1] ||
        normalized.day != parts[2] ||
        parts[3] > 23 ||
        parts[4] > 59 ||
        parts[5] > 59 ||
        (zone != 'Z' &&
            (int.parse(zone.substring(1, 3)) > 23 ||
                int.parse(zone.substring(4)) > 59))) {
      throw FormatException('$key contains an invalid date or time');
    }
    return DateTime.parse(value).toUtc();
  }
}
