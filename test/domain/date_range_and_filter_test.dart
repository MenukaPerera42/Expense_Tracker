import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_filter.dart';
import 'package:expense_tracker/domain/usecases/month_navigation.dart';

void main() {
  group('DateRange', () {
    final start = DateTime(2026, 3, 10);
    final end = DateTime(2026, 3, 20);

    test('valid range initializes successfully and normalizes boundaries', () {
      final range = DateRange(start: start, end: end);
      expect(range.start, start);
      expect(range.end, end);
    });

    test('same start and end is accepted as a single-day range', () {
      final range = DateRange(start: start, end: start);
      expect(range.start, range.end);
      expect(range.contains(start), isTrue);
    });

    test('start after end throws AssertionError', () {
      expect(
        () => DateRange(start: end, end: start),
        throwsA(isA<AssertionError>()),
      );
    });

    test('contains matches inclusive start, end, and middle instants', () {
      final range = DateRange(start: start, end: end);
      expect(range.contains(start), isTrue);
      expect(range.contains(end), isTrue);
      expect(range.contains(DateTime(2026, 3, 15, 12, 30)), isTrue);
      expect(range.contains(DateTime(2026, 3, 9, 23, 59, 59)), isFalse);
      expect(range.contains(DateTime(2026, 3, 21)), isFalse);
    });

    test('equality and hashCode support value comparison', () {
      final r1 = DateRange(start: start, end: end);
      final r2 = DateRange(
        start: DateTime(2026, 3, 10),
        end: DateTime(2026, 3, 20),
      );
      final r3 = DateRange(start: start, end: DateTime(2026, 3, 21));

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
      expect(r1, isNot(equals(r3)));
    });
  });

  group('ExpenseFilter mutual exclusion and state transitions', () {
    test('initial state has no active filters and default sort', () {
      const filter = ExpenseFilter.initial;
      expect(filter.category, isNull);
      expect(filter.date, isNull);
      expect(filter.dateRange, isNull);
      expect(filter.month, isNull);
      expect(filter.sort, ExpenseSortOption.newest);
      expect(filter.isActive, isFalse);
    });

    test('setting date clears dateRange and month', () {
      final base = ExpenseFilter.initial
          .copyWithDateRange(
            DateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 10)),
          )
          .copyWithMonth(DateTime(2026, 2, 1));

      final updated = base.copyWithDate(DateTime(2026, 3, 15));
      expect(updated.date, DateTime(2026, 3, 15));
      expect(updated.dateRange, isNull);
      expect(updated.month, isNull);
      expect(updated.isActive, isTrue);
    });

    test('setting dateRange clears date and month', () {
      final base = ExpenseFilter.initial
          .copyWithDate(DateTime(2026, 3, 15))
          .copyWithMonth(DateTime(2026, 2, 1));

      final range = DateRange(
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 10),
      );
      final updated = base.copyWithDateRange(range);
      expect(updated.dateRange, range);
      expect(updated.date, isNull);
      expect(updated.month, isNull);
      expect(updated.isActive, isTrue);
    });

    test('setting month clears date and dateRange', () {
      final base = ExpenseFilter.initial
          .copyWithDate(DateTime(2026, 3, 15))
          .copyWithDateRange(
            DateRange(start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 10)),
          );

      final updated = base.copyWithMonth(DateTime(2026, 5, 1));
      expect(updated.month, MonthNavigation.normalize(DateTime(2026, 5, 1)));
      expect(updated.date, isNull);
      expect(updated.dateRange, isNull);
      expect(updated.isActive, isTrue);
    });

    test('category filter activates filter independently of date', () {
      final filter = ExpenseFilter.initial.copyWithCategory(
        ExpenseCategory.food,
      );
      expect(filter.category, ExpenseCategory.food);
      expect(filter.isActive, isTrue);

      final cleared = filter.copyWithCategory(null);
      expect(cleared.category, isNull);
      expect(cleared.isActive, isFalse);
    });

    test('changing sort does not activate filter', () {
      final filter = ExpenseFilter.initial.copyWithSort(
        ExpenseSortOption.highestAmount,
      );
      expect(filter.sort, ExpenseSortOption.highestAmount);
      expect(filter.isActive, isFalse);
    });

    test('equality and hashCode support comparison', () {
      final f1 = ExpenseFilter.initial.copyWithCategory(ExpenseCategory.travel);
      final f2 = ExpenseFilter.initial.copyWithCategory(ExpenseCategory.travel);
      final f3 = ExpenseFilter.initial.copyWithCategory(ExpenseCategory.bills);

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1, isNot(equals(f3)));
    });
  });
}
