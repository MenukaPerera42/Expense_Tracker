import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/presentation/widgets/expense_list_item.dart';
import 'package:expense_tracker/presentation/widgets/expense_list_skeleton.dart';
import 'package:expense_tracker/presentation/widgets/scrollable_fill.dart';

void main() {
  group('ExpenseListItem touch targets', () {
    testWidgets('edit and delete actions meet a 44x44 minimum tap size', (
      tester,
    ) async {
      final expense = Expense(
        id: 'e1',
        userId: 'user-1',
        title: 'Coffee',
        amount: 5,
        category: ExpenseCategory.food,
        date: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExpenseListItem(expense: expense, onEdit: () {}),
            ),
          ),
        ),
      );
      final editSize = tester.getSize(find.byTooltip('Edit expense'));
      final deleteSize = tester.getSize(find.byTooltip('Delete expense'));
      expect(editSize.width, greaterThanOrEqualTo(44));
      expect(editSize.height, greaterThanOrEqualTo(44));
      expect(deleteSize.width, greaterThanOrEqualTo(44));
      expect(deleteSize.height, greaterThanOrEqualTo(44));
    });
  });

  group('ExpenseListSkeleton', () {
    testWidgets('renders the requested number of placeholder rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ExpenseListSkeleton(itemCount: 3)),
        ),
      );
      expect(find.byType(Card), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ExpenseListSkeleton()),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('ScrollableFill', () {
    testWidgets('stretches short content to fill the viewport height', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScrollableFill(child: Center(child: Text('Hello'))),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('supports a pull-to-refresh gesture even with short content', (
      tester,
    ) async {
      var refreshed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefreshIndicator(
              onRefresh: () async => refreshed = true,
              child: const ScrollableFill(child: Center(child: Text('Hi'))),
            ),
          ),
        ),
      );
      await tester.fling(find.text('Hi'), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(refreshed, isTrue);
    });
  });
}
