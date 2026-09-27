import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/data/models/expense_mapper.dart';

Expense sample({
  num amount = 1250.75,
  String? note = 'Lunch',
  DateTime? date,
}) => Expense(
  id: 'expense-1',
  userId: 'user-1',
  title: 'Lunch',
  amount: amount,
  category: ExpenseCategory.food,
  date: date ?? DateTime.utc(2026, 9, 27, 12, 30, 4, 123, 456),
  note: note,
  createdAt: DateTime.utc(2026, 9, 27),
  updatedAt: DateTime.utc(2026, 9, 28),
);

void main() {
  test('JSON round trip survives actual JSON encoding', () {
    final expense = sample();
    final json = ExpenseMapper.toJson(expense);
    expect(json['category'], 'food');
    expect(json['date'], '2026-09-27T12:30:04.123456Z');
    expect(json['amount'], 1250.75);
    expect(
      ExpenseMapper.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      ),
      expense,
    );
  });
  test(
    'Firestore uses timestamps and document identity without mutating input',
    () {
      final expense = sample();
      final data = ExpenseMapper.toFirestore(expense);
      expect(data.containsKey('id'), isFalse);
      expect(data['date'], isA<Timestamp>());
      expect((data['date'] as Timestamp).nanoseconds, 123456000);
      expect(
        ExpenseMapper.fromFirestore(data, documentId: expense.id),
        expense,
      );
      expect(data.containsKey('id'), isFalse);
      expect(
        () => ExpenseMapper.fromFirestore({
          ...data,
          'id': 'other',
        }, documentId: expense.id),
        throwsFormatException,
      );
    },
  );
  test('missing/null/empty notes are supported while wrong types fail', () {
    final data = ExpenseMapper.toJson(sample())..remove('note');
    expect(ExpenseMapper.fromJson(data).note, isNull);
    expect(ExpenseMapper.fromJson({...data, 'note': null}), sample(note: null));
    expect(ExpenseMapper.fromJson({...data, 'note': ''}).note, '');
    expect(
      () => ExpenseMapper.fromJson({...data, 'note': 4}),
      throwsFormatException,
    );
    final firestore = ExpenseMapper.toFirestore(sample())..remove('note');
    expect(
      ExpenseMapper.fromFirestore(firestore, documentId: 'expense-1').note,
      isNull,
    );
  });
  test(
    'every category has a stable round-trip code; unknown codes never default',
    () {
      expect(ExpenseCategory.values.map((c) => c.code).toSet().length, 9);
      for (final category in ExpenseCategory.values) {
        expect(ExpenseCategory.fromCode(category.code), category);
        final data = ExpenseMapper.toJson(sample())
          ..['category'] = category.code;
        expect(ExpenseMapper.fromJson(data).category, category);
      }
      for (final bad in ['FOOD', '', 'new-category']) {
        expect(() => ExpenseCategory.fromCode(bad), throwsFormatException);
      }
    },
  );
  test(
    'UTC normalization handles explicit timezone offsets and microseconds',
    () {
      final data = ExpenseMapper.toJson(sample());
      data['date'] = '2026-09-27T18:00:04.123456+05:30';
      expect(ExpenseMapper.fromJson(data), sample());
      final local = DateTime(2026, 9, 27, 12);
      expect(sample(date: local).date, local.toUtc());
      expect(sample(date: local).date.isUtc, isTrue);
      data['date'] = '2024-02-29T00:00:00Z';
      expect(ExpenseMapper.fromJson(data).date, DateTime.utc(2024, 2, 29));
    },
  );
  test('invalid dates, rollover dates and timezone ambiguity are rejected', () {
    for (final bad in [
      null,
      42,
      'invalid',
      '2026-02-30T00:00:00Z',
      '2026-09-27',
      '2026-09-27T12:00:00',
      '2026-09-27T24:00:00Z',
      '2026-09-27T00:00:00+05:99',
      '2026-09-27T00:00:00.1234567Z',
    ]) {
      expect(
        () => ExpenseMapper.fromJson({
          ...ExpenseMapper.toJson(sample()),
          'date': bad,
        }),
        throwsFormatException,
        reason: '$bad',
      );
    }
    for (final key in ['date', 'createdAt', 'updatedAt']) {
      expect(
        () => ExpenseMapper.fromFirestore({
          ...ExpenseMapper.toFirestore(sample()),
          key: '2026-09-27',
        }, documentId: 'expense-1'),
        throwsFormatException,
      );
    }
  });
  test(
    'missing required fields and wrong field types fail instead of defaulting',
    () {
      for (final key in [
        'id',
        'userId',
        'title',
        'amount',
        'category',
        'date',
        'createdAt',
        'updatedAt',
      ]) {
        final data = ExpenseMapper.toJson(sample())..remove(key);
        expect(
          () => ExpenseMapper.fromJson(data),
          throwsFormatException,
          reason: key,
        );
      }
      for (final entry in {
        'id': '',
        'userId': 'a/b',
        'title': '  ',
        'category': 1,
        'amount': '12.5',
      }.entries) {
        expect(
          () => ExpenseMapper.fromJson({
            ...ExpenseMapper.toJson(sample()),
            entry.key: entry.value,
          }),
          throwsFormatException,
        );
      }
      final reversed = ExpenseMapper.toJson(sample())
        ..['updatedAt'] = '2025-01-01T00:00:00Z';
      expect(() => ExpenseMapper.fromJson(reversed), throwsFormatException);
    },
  );
  test('amount rejects nonfinite, nonpositive and unsafe integers without coercion', () {
    for (final amount in [
      0,
      -1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      9007199254740993,
    ]) {
      expect(() => sample(amount: amount), throwsArgumentError);
      expect(
        () => ExpenseMapper.fromJson({
          ...ExpenseMapper.toJson(sample()),
          'amount': amount,
        }),
        throwsFormatException,
      );
    }
    expect(
      ExpenseMapper.fromJson({...ExpenseMapper.toJson(sample()), 'amount': 12})
          .amount,
      12.0,
    );
    expect(sample(amount: 0.01).amount, 0.01);
  });
  test(
    'equality and hash include every field and support set deduplication',
    () {
      final expense = sample();
      expect(
        {
          expense,
          sample(),
          ExpenseMapper.fromJson(ExpenseMapper.toJson(expense)),
        }.length,
        1,
      );
      final alternatives = {
        'id': 'expense-2',
        'userId': 'user-2',
        'title': 'Dinner',
        'amount': 5,
        'category': 'other',
        'date': '2026-09-28T00:00:00Z',
        'note': null,
        'createdAt': '2026-09-26T00:00:00Z',
        'updatedAt': '2026-09-29T00:00:00Z',
      };
      for (final entry in alternatives.entries) {
        expect(
          ExpenseMapper.fromJson({
            ...ExpenseMapper.toJson(expense),
            entry.key: entry.value,
          }),
          isNot(expense),
          reason: entry.key,
        );
      }
    },
  );
}
