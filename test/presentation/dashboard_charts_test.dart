import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/usecases/expense_chart_data.dart';
import 'package:expense_tracker/presentation/widgets/category_pie_chart.dart';
import 'package:expense_tracker/presentation/widgets/monthly_spending_chart.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  group('CategoryPieChart', () {
    testWidgets('zero data shows an empty message instead of a chart', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const CategoryPieChart(slices: [])));
      expect(find.text('No spending yet'), findsOneWidget);
      expect(find.byType(PieChart), findsNothing);
    });

    testWidgets('a single category renders as one full slice', (tester) async {
      await tester.pumpWidget(
        _app(
          const CategoryPieChart(
            slices: [
              CategorySlice(
                category: ExpenseCategory.food,
                amount: 42,
                percentage: 1.0,
              ),
            ],
          ),
        ),
      );
      // fl_chart paints section titles onto its own canvas rather than
      // composing Text widgets, so this only asserts the chart renders
      // cleanly for a single, 100%-share slice — the label content itself
      // is a domain-level concern already covered by
      // test/domain/expense_chart_data_test.dart.
      expect(find.byType(PieChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('many categories all render without error', (tester) async {
      final slices = [
        for (final category in ExpenseCategory.values)
          CategorySlice(
            category: category,
            amount: (category.index + 1) * 10,
            percentage: (category.index + 1) / 45,
          ),
      ];
      await tester.pumpWidget(_app(CategoryPieChart(slices: slices)));
      expect(find.byType(PieChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error in dark mode', (tester) async {
      await tester.pumpWidget(
        _app(
          const CategoryPieChart(
            slices: [
              CategorySlice(
                category: ExpenseCategory.food,
                amount: 30,
                percentage: 0.75,
              ),
              CategorySlice(
                category: ExpenseCategory.transport,
                amount: 10,
                percentage: 0.25,
              ),
            ],
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(find.byType(PieChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a very large amount still renders correctly', (tester) async {
      await tester.pumpWidget(
        _app(
          const CategoryPieChart(
            slices: [
              CategorySlice(
                category: ExpenseCategory.bills,
                amount: 999999999.99,
                percentage: 1.0,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PieChart), findsOneWidget);
    });
  });

  group('MonthlySpendingChart', () {
    testWidgets('zero data (all months empty) shows an empty message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          MonthlySpendingChart(
            points: [
              MonthlySpendingPoint(month: DateTime(2026, 8), total: 0),
              MonthlySpendingPoint(month: DateTime(2026, 9), total: 0),
            ],
          ),
        ),
      );
      expect(find.text('No spending in this period yet'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('renders a bar per month with a month label', (tester) async {
      await tester.pumpWidget(
        _app(
          MonthlySpendingChart(
            points: [
              MonthlySpendingPoint(month: DateTime(2026, 7), total: 50),
              MonthlySpendingPoint(month: DateTime(2026, 8), total: 120),
              MonthlySpendingPoint(month: DateTime(2026, 9), total: 80),
            ],
          ),
        ),
      );
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('Sep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a large amount does not break layout or crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          MonthlySpendingChart(
            points: [
              MonthlySpendingPoint(month: DateTime(2026, 8), total: 10),
              MonthlySpendingPoint(
                month: DateTime(2026, 9),
                total: 999999999.99,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders without error in dark mode', (tester) async {
      await tester.pumpWidget(
        _app(
          MonthlySpendingChart(
            points: [MonthlySpendingPoint(month: DateTime(2026, 9), total: 25)],
          ),
          brightness: Brightness.dark,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsOneWidget);
    });
  });
}
