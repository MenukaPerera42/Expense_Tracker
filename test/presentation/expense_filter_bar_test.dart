import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/routing/app_router.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

Expense _expense({
  required String id,
  required String title,
  required num amount,
  ExpenseCategory category = ExpenseCategory.food,
  DateTime? date,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: amount,
  category: category,
  date: date ?? DateTime.utc(2026, 9, 20),
  createdAt: DateTime.utc(2026, 9, 20),
  updatedAt: DateTime.utc(2026, 9, 20),
);

void main() {
  late MockExpenseRepository repository;

  setUp(() {
    repository = MockExpenseRepository();
  });

  Future<ProviderContainer> mount(WidgetTester tester) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appInitializerProvider.overrideWithValue(() async {}),
        authStateProvider.overrideWith((ref) async* {
          yield const AuthUser(id: 'user-1');
        }),
        expenseRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExpenseTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go(AppRouter.expenseHistoryPath);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('selecting a category filter narrows the list', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Lunch', amount: 10, category: ExpenseCategory.food),
        _expense(id: 'b', title: 'Bus', amount: 3, category: ExpenseCategory.transport),
      ]),
    );
    await mount(tester);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Bus'), findsOneWidget);

    await tester.tap(find.widgetWithText(InputChip, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
    await tester.pumpAndSettle();

    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
    expect(find.widgetWithText(InputChip, 'Transport'), findsOneWidget);
  });

  testWidgets(
    'a filter combination matching nothing shows the empty-filtered state, '
    'and Clear filters restores the full list',
    (tester) async {
      when(() => repository.watchExpenses()).thenAnswer(
        (_) => Stream.value([
          _expense(id: 'a', title: 'Lunch', amount: 10, category: ExpenseCategory.food),
        ]),
      );
      await mount(tester);

      await tester.tap(find.widgetWithText(InputChip, 'Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Transport'));
      await tester.pumpAndSettle();

      expect(find.text('No expenses match your filters'), findsOneWidget);
      expect(find.text('Lunch'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
      await tester.pumpAndSettle();

      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('No expenses match your filters'), findsNothing);
    },
  );

  testWidgets('sorting by lowest amount reorders the list', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Big', amount: 100),
        _expense(id: 'b', title: 'Small', amount: 5),
      ]),
    );
    await mount(tester);

    await tester.tap(find.widgetWithText(Chip, 'Newest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lowest amount').last);
    await tester.pumpAndSettle();

    final smallY = tester.getTopLeft(find.text('Small')).dy;
    final bigY = tester.getTopLeft(find.text('Big')).dy;
    expect(smallY, lessThan(bigY));
  });
}
