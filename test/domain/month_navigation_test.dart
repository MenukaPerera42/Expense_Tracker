import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/usecases/month_navigation.dart';

void main() {
  group('normalize', () {
    test('pins to the first of the month at midnight, local time', () {
      final normalized = MonthNavigation.normalize(
        DateTime(2026, 9, 17, 14, 30),
      );
      expect(normalized, DateTime(2026, 9));
    });
  });

  group('previous', () {
    test('steps back a month', () {
      expect(MonthNavigation.previous(DateTime(2026, 9)), DateTime(2026, 8));
    });

    test('rolls back across a year boundary', () {
      expect(MonthNavigation.previous(DateTime(2026, 1)), DateTime(2025, 12));
    });
  });

  group('next', () {
    test('steps forward a month when that month has already happened', () {
      final result = MonthNavigation.next(
        DateTime(2026, 6),
        now: DateTime(2026, 9, 10),
      );
      expect(result, DateTime(2026, 7));
    });

    test('rolls forward across a year boundary', () {
      final result = MonthNavigation.next(
        DateTime(2025, 12),
        now: DateTime(2026, 9, 10),
      );
      expect(result, DateTime(2026, 1));
    });

    test('is capped at the current month and will not go into the future', () {
      final now = DateTime(2026, 9, 10);
      final result = MonthNavigation.next(DateTime(2026, 9), now: now);
      expect(result, DateTime(2026, 9));
    });
  });

  group('isCurrentMonth', () {
    test('true for the month containing now', () {
      expect(
        MonthNavigation.isCurrentMonth(
          DateTime(2026, 9, 1),
          now: DateTime(2026, 9, 20),
        ),
        isTrue,
      );
    });

    test('false for any other month', () {
      expect(
        MonthNavigation.isCurrentMonth(
          DateTime(2026, 8, 1),
          now: DateTime(2026, 9, 20),
        ),
        isFalse,
      );
    });
  });

  group('isSameMonth', () {
    test('true regardless of day/time within the same month', () {
      expect(
        MonthNavigation.isSameMonth(
          DateTime(2026, 9, 1, 0, 0),
          DateTime(2026, 9, 30, 23, 59),
        ),
        isTrue,
      );
    });

    test('false across a month boundary', () {
      expect(
        MonthNavigation.isSameMonth(DateTime(2026, 9, 30), DateTime(2026, 10, 1)),
        isFalse,
      );
    });
  });

  group('isBeforeMonth', () {
    test('true when the first month precedes the second', () {
      expect(
        MonthNavigation.isBeforeMonth(DateTime(2026, 8), DateTime(2026, 9)),
        isTrue,
      );
    });

    test('false for the same month or a later one', () {
      expect(
        MonthNavigation.isBeforeMonth(DateTime(2026, 9), DateTime(2026, 9)),
        isFalse,
      );
      expect(
        MonthNavigation.isBeforeMonth(DateTime(2026, 10), DateTime(2026, 9)),
        isFalse,
      );
    });
  });
}
