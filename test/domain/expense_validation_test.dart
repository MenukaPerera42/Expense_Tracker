import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/domain/usecases/expense_validation.dart';

void main() {
  group('title', () {
    test('rejects empty/whitespace-only input and trims before checking', () {
      expect(ExpenseValidation.title(''), isNotNull);
      expect(ExpenseValidation.title('   '), isNotNull);
      expect(ExpenseValidation.title(null), isNotNull);
      expect(ExpenseValidation.title('  Lunch  '), isNull);
    });
    test('rejects titles beyond the configured maximum length', () {
      expect(
        ExpenseValidation.title('a' * ExpenseValidation.titleMaxLength),
        isNull,
      );
      expect(
        ExpenseValidation.title('a' * (ExpenseValidation.titleMaxLength + 1)),
        isNotNull,
      );
    });
  });

  group('amount', () {
    test('requires a value', () {
      expect(ExpenseValidation.amount(''), 'Enter an amount.');
      expect(ExpenseValidation.amount(null), 'Enter an amount.');
    });
    test('rejects non-numeric and malformed numeric input', () {
      expect(ExpenseValidation.amount('abc'), 'Enter a valid number.');
      expect(ExpenseValidation.amount('1.2.3'), 'Enter a valid number.');
      expect(ExpenseValidation.amount('NaN'), 'Enter a valid number.');
    });
    test('rejects zero and negative amounts', () {
      expect(
        ExpenseValidation.amount('0'),
        'Amount must be greater than zero.',
      );
      expect(
        ExpenseValidation.amount('0.0'),
        'Amount must be greater than zero.',
      );
      expect(
        ExpenseValidation.amount('-5'),
        'Amount must be greater than zero.',
      );
      expect(
        ExpenseValidation.amount('-0.01'),
        'Amount must be greater than zero.',
      );
    });
    test('rejects amounts beyond the sanity ceiling', () {
      expect(ExpenseValidation.amount('1000000000'), 'Amount is too large.');
    });
    test('accepts positive decimal values', () {
      expect(ExpenseValidation.amount('12.5'), isNull);
      expect(ExpenseValidation.amount('  0.01  '), isNull);
      expect(ExpenseValidation.amount('250'), isNull);
    });
  });

  group('note', () {
    test('is optional', () {
      expect(ExpenseValidation.note(''), isNull);
      expect(ExpenseValidation.note(null), isNull);
      expect(ExpenseValidation.note('   '), isNull);
    });
    test('rejects notes beyond the configured maximum length', () {
      expect(
        ExpenseValidation.note('a' * ExpenseValidation.noteMaxLength),
        isNull,
      );
      expect(
        ExpenseValidation.note('a' * (ExpenseValidation.noteMaxLength + 1)),
        'Use at most ${ExpenseValidation.noteMaxLength} characters.',
      );
    });
  });

  group('date', () {
    test('accepts today and the past', () {
      final now = DateTime.utc(2026, 9, 27, 12);
      expect(ExpenseValidation.date(now, now: now), isNull);
      expect(
        ExpenseValidation.date(now.subtract(const Duration(days: 1)), now: now),
        isNull,
      );
    });
    test('rejects any date after the reference moment', () {
      final now = DateTime.utc(2026, 9, 27, 12);
      expect(
        ExpenseValidation.date(now.add(const Duration(days: 1)), now: now),
        'Date cannot be in the future.',
      );
      expect(
        ExpenseValidation.date(now.add(const Duration(minutes: 1)), now: now),
        'Date cannot be in the future.',
      );
    });
  });
}
