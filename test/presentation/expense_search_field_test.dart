import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/presentation/providers/expense_providers.dart';
import 'package:expense_tracker/presentation/widgets/expense_list_item.dart';
import 'package:expense_tracker/routing/app_router.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

Expense _expense({
  required String id,
  required String title,
  String? note,
  ExpenseCategory category = ExpenseCategory.food,
  DateTime? date,
}) => Expense(
  id: id,
  userId: 'user-1',
  title: title,
  amount: 10,
  category: category,
  note: note,
  date: date ?? DateTime.utc(2026, 9, 20),
  createdAt: DateTime.utc(2026, 9, 20),
  updatedAt: DateTime.utc(2026, 9, 20),
);

void main() {
  late MockExpenseRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  /// Types [text], lets the search field's debounce elapse, and settles.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('typing does not filter the list until the debounce elapses', (
    tester,
  ) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Team lunch'),
        _expense(id: 'b', title: 'Bus fare'),
      ]),
    );
    await mount(tester);

    await tester.enterText(find.byType(TextField), 'lunch');
    await tester.pump();
    // Before the debounce elapses, both rows are still shown.
    expect(find.text('Bus fare'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Bus fare'), findsNothing);
    expect(find.text('Team lunch'), findsOneWidget);
  });

  testWidgets('matches by title', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Team lunch'),
        _expense(id: 'b', title: 'Bus fare'),
      ]),
    );
    await mount(tester);
    await search(tester, 'bus');
    expect(find.text('Bus fare'), findsOneWidget);
    expect(find.text('Team lunch'), findsNothing);
  });

  testWidgets('matches by note', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Groceries', note: 'Weekly shop with Alex'),
        _expense(id: 'b', title: 'Bus fare'),
      ]),
    );
    await mount(tester);
    await search(tester, 'Alex');
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Bus fare'), findsNothing);
  });

  testWidgets('search is case-insensitive', (tester) async {
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value([_expense(id: 'a', title: 'Team Lunch')]));
    await mount(tester);
    await search(tester, 'TEAM LUNCH');
    expect(find.text('Team Lunch'), findsOneWidget);
  });

  testWidgets('a search matching nothing shows the empty state', (
    tester,
  ) async {
    when(
      () => repository.watchExpenses(),
    ).thenAnswer((_) => Stream.value([_expense(id: 'a', title: 'Team lunch')]));
    await mount(tester);
    await search(tester, 'taxi');
    expect(find.text('No matching expenses'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Clear search'), findsOneWidget);
  });

  testWidgets('search combines with an active category filter', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Team lunch', category: ExpenseCategory.food),
        _expense(
          id: 'b',
          title: 'Lunch bus pass',
          category: ExpenseCategory.transport,
        ),
      ]),
    );
    await mount(tester);
    await tester.tap(find.widgetWithText(InputChip, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Food'));
    await tester.pumpAndSettle();

    await search(tester, 'lunch');
    // Both titles contain "lunch", but the transport one is excluded by
    // the category filter regardless of the search match.
    expect(find.text('Team lunch'), findsOneWidget);
    expect(find.text('Lunch bus pass'), findsNothing);
  });

  testWidgets('search combines with an active date filter', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Team lunch', date: DateTime.utc(2026, 9, 5)),
        _expense(id: 'b', title: 'Team lunch', date: DateTime.utc(2026, 9, 6)),
      ]),
    );
    final container = await mount(tester);
    // Drives the filter through the provider directly rather than the
    // platform date picker (already exercised, without this brittleness,
    // by ExpenseFilterBar's own tests) — the point here is proving search
    // and an active date filter combine correctly.
    container
        .read(expenseFilterProvider.notifier)
        .setDate(DateTime.utc(2026, 9, 5));
    await tester.pumpAndSettle();

    await search(tester, 'lunch');
    // Both rows match "lunch", but only the Sept 5 one survives the date
    // filter that's active alongside the search.
    expect(find.text('Team lunch'), findsOneWidget);
    final rows = find.byType(ExpenseListItem);
    expect(rows, findsOneWidget);
  });

  testWidgets('clear search restores the unfiltered list', (tester) async {
    when(() => repository.watchExpenses()).thenAnswer(
      (_) => Stream.value([
        _expense(id: 'a', title: 'Team lunch'),
        _expense(id: 'b', title: 'Bus fare'),
      ]),
    );
    await mount(tester);
    await search(tester, 'lunch');
    expect(find.text('Bus fare'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Bus fare'), findsOneWidget);
    expect(find.text('Team lunch'), findsOneWidget);
  });
}
