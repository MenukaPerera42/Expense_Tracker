import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/entities/expense_category.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/domain/usecases/expense_filter.dart';
import 'package:expense_tracker/domain/usecases/month_navigation.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/presentation/providers/expense_providers.dart';

class MockExpenseRepository extends Mock implements ExpenseRepository {}

final _now = DateTime.now();
DateTime _thisMonth(int day) => DateTime(_now.year, _now.month, day);

Expense _createTestExpense({
  required String id,
  required String title,
  required num amount,
  DateTime? date,
  ExpenseCategory category = ExpenseCategory.food,
  String? note,
}) {
  final d = date ?? _thisMonth(5);
  return Expense(
    id: id,
    userId: 'user-1',
    title: title,
    amount: amount,
    category: category,
    date: d,
    note: note,
    createdAt: d,
    updatedAt: d,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      _createTestExpense(id: 'fallback', title: 'Fallback', amount: 10),
    );
  });

  late MockExpenseRepository repository;

  setUp(() {
    repository = MockExpenseRepository();
    when(() => repository.newExpenseId()).thenReturn('gen-id-123');
  });

  group('expenseListProvider and expenseByIdProvider', () {
    test('expenseListProvider yields live updates from repository', () async {
      final expenses = [
        _createTestExpense(id: '1', title: 'Coffee', amount: 4.5),
        _createTestExpense(id: '2', title: 'Book', amount: 15),
      ];
      final streamController = StreamController<List<Expense>>();
      addTearDown(streamController.close);
      when(() => repository.watchExpenses())
          .thenAnswer((_) => streamController.stream);

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final values = <AsyncValue<List<Expense>>>[];
      final sub = container.listen<AsyncValue<List<Expense>>>(
        expenseListProvider,
        (_, next) => values.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      expect(values.first, isA<AsyncLoading>());

      // Allow repository FutureProvider to resolve and yield* to attach listener
      await pumpEventQueue();
      streamController.add(expenses);
      await pumpEventQueue();

      expect(values.last, isA<AsyncData<List<Expense>>>());
      expect(values.last.value?.length, 2);
      expect(values.last.value?.first.title, 'Coffee');
    });

    test('expenseByIdProvider fetches single expense by id', () async {
      final expense = _createTestExpense(
        id: 'exp-1',
        title: 'Dinner',
        amount: 35,
      );
      when(() => repository.getExpenseById('exp-1'))
          .thenAnswer((_) async => expense);
      when(() => repository.getExpenseById('missing'))
          .thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final found = await container.read(expenseByIdProvider('exp-1').future);
      expect(found?.title, 'Dinner');

      final notFound = await container.read(
        expenseByIdProvider('missing').future,
      );
      expect(notFound, isNull);
    });
  });

  group('AddExpenseController', () {
    test(
      'submits successfully when authenticated and saves to repository',
      () async {
        when(() => repository.createExpense(any())).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) async* {
              yield const AuthUser(id: 'user-1');
            }),
            expenseRepositoryProvider.overrideWith((ref) async => repository),
          ],
        );
        addTearDown(container.dispose);

        final authSub = container.listen(authStateProvider, (_, _) {});
        addTearDown(authSub.close);
        await container.read(authStateProvider.future);

        final controller = container.read(
          addExpenseControllerProvider.notifier,
        );
        expect(
          container.read(addExpenseControllerProvider),
          const AsyncData<void>(null),
        );

        await controller.submit(
          title: 'Groceries',
          amount: '45.50',
          category: ExpenseCategory.food,
          date: DateTime.utc(2026, 4, 1),
          note: 'Weekly essentials',
        );

        expect(container.read(addExpenseControllerProvider).hasError, isFalse);
        expect(container.read(addExpenseControllerProvider).isLoading, isFalse);

        final captured =
            verify(() => repository.createExpense(captureAny())).captured.single
                as Expense;
        expect(captured.id, 'gen-id-123');
        expect(captured.userId, 'user-1');
        expect(captured.title, 'Groceries');
        expect(captured.amount, 45.50);
        expect(captured.note, 'Weekly essentials');
      },
    );

    test(
      'submit fails with unauthenticated error when user is not signed in',
      () async {
        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) async* {
              yield null;
            }),
            expenseRepositoryProvider.overrideWith((ref) async => repository),
          ],
        );
        addTearDown(container.dispose);

        final authSub = container.listen(authStateProvider, (_, _) {});
        addTearDown(authSub.close);
        await container.read(authStateProvider.future);

        final controller = container.read(
          addExpenseControllerProvider.notifier,
        );
        await controller.submit(
          title: 'Lunch',
          amount: '12',
          category: ExpenseCategory.food,
          date: DateTime.utc(2026, 4, 1),
        );

        final state = container.read(addExpenseControllerProvider);
        expect(state.hasError, isTrue);
        expect(state.error, isA<AppException>());
        expect(
          (state.error as AppException).code,
          AppErrorCode.unauthenticated,
        );
      },
    );

    test(
      'submit propagates repository failure to state as AsyncError',
      () async {
        when(() => repository.createExpense(any())).thenThrow(
          const AppException(AppErrorCode.unavailable, 'Network error'),
        );

        final container = ProviderContainer(
          overrides: [
            authStateProvider.overrideWith((ref) async* {
              yield const AuthUser(id: 'user-1');
            }),
            expenseRepositoryProvider.overrideWith((ref) async => repository),
          ],
        );
        addTearDown(container.dispose);

        final authSub = container.listen(authStateProvider, (_, _) {});
        addTearDown(authSub.close);
        await container.read(authStateProvider.future);

        final controller = container.read(
          addExpenseControllerProvider.notifier,
        );
        await controller.submit(
          title: 'Taxi',
          amount: '20',
          category: ExpenseCategory.transport,
          date: DateTime.utc(2026, 4, 1),
        );

        final state = container.read(addExpenseControllerProvider);
        expect(state.hasError, isTrue);
        expect((state.error as AppException).code, AppErrorCode.unavailable);
      },
    );
  });

  group('EditExpenseController', () {
    test('submits successfully and preserves immutable fields', () async {
      when(() => repository.updateExpense(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final original = _createTestExpense(
        id: 'orig-id',
        title: 'Old Title',
        amount: 50,
      );

      final controller = container.read(editExpenseControllerProvider.notifier);
      await controller.submit(
        original: original,
        title: 'New Title',
        amount: '75',
        category: ExpenseCategory.shopping,
        date: DateTime.utc(2026, 5, 2),
        note: 'Updated note',
      );

      expect(container.read(editExpenseControllerProvider).hasError, isFalse);
      final captured =
          verify(() => repository.updateExpense(captureAny())).captured.single
              as Expense;
      expect(captured.id, original.id);
      expect(captured.userId, original.userId);
      expect(captured.createdAt, original.createdAt);
      expect(captured.title, 'New Title');
      expect(captured.amount, 75.0);
      expect(captured.category, ExpenseCategory.shopping);
      expect(captured.note, 'Updated note');
    });

    test('submit sets AsyncError on repository update failure', () async {
      when(() => repository.updateExpense(any()))
          .thenThrow(const AppException(AppErrorCode.notFound, 'Not found'));

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final original = _createTestExpense(
        id: 'orig-id',
        title: 'Old',
        amount: 10,
      );
      final controller = container.read(editExpenseControllerProvider.notifier);

      await controller.submit(
        original: original,
        title: 'New',
        amount: '10',
        category: ExpenseCategory.other,
        date: DateTime.utc(2026, 5, 2),
      );

      final state = container.read(editExpenseControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as AppException).code, AppErrorCode.notFound);
    });
  });

  group('DeleteExpenseController', () {
    test('tracks in-flight loading and updates per-id state map', () async {
      final completer = Completer<void>();
      when(() => repository.deleteExpense('id-1'))
          .thenAnswer((_) => completer.future);

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        deleteExpenseControllerProvider.notifier,
      );
      final future = controller.delete('id-1');

      final loadingState = container.read(deleteExpenseControllerProvider);
      expect(loadingState['id-1']?.isLoading, isTrue);

      completer.complete();
      await future;

      final successState = container.read(deleteExpenseControllerProvider);
      expect(successState['id-1']?.hasValue, isTrue);
      expect(successState['id-1']?.isLoading, isFalse);

      controller.clear('id-1');
      expect(
        container.read(deleteExpenseControllerProvider).containsKey('id-1'),
        isFalse,
      );
    });

    test('tracks error state per id on deletion failure', () async {
      when(() => repository.deleteExpense('id-2')).thenThrow(
        const AppException(AppErrorCode.permissionDenied, 'Cannot delete'),
      );

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        deleteExpenseControllerProvider.notifier,
      );
      await controller.delete('id-2');

      final state = container.read(deleteExpenseControllerProvider);
      expect(state['id-2']?.hasError, isTrue);
      expect(
        (state['id-2']?.error as AppException).code,
        AppErrorCode.permissionDenied,
      );
    });
  });

  group('Month, Filter, and Search controllers and derived providers', () {
    test('SelectedMonthController navigates previous and next, capped to current month', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(selectedMonthProvider);
      expect(MonthNavigation.isCurrentMonth(initial), isTrue);

      final notifier = container.read(selectedMonthProvider.notifier);
      // nextMonth at current month should stay at current month
      notifier.nextMonth();
      expect(container.read(selectedMonthProvider), initial);

      // previousMonth steps back
      notifier.previousMonth();
      expect(
        MonthNavigation.isBeforeMonth(
          container.read(selectedMonthProvider),
          initial,
        ),
        isTrue,
      );

      // nextMonth returns to initial
      notifier.nextMonth();
      expect(container.read(selectedMonthProvider), initial);
    });

    test(
      'ExpenseFilterController updates filter state and clear restores initial',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(expenseFilterProvider.notifier);
        expect(container.read(expenseFilterProvider).isActive, isFalse);

        notifier.setCategory(ExpenseCategory.entertainment);
        expect(
          container.read(expenseFilterProvider).category,
          ExpenseCategory.entertainment,
        );
        expect(container.read(expenseFilterProvider).isActive, isTrue);

        notifier.setSort(ExpenseSortOption.lowestAmount);
        expect(
          container.read(expenseFilterProvider).sort,
          ExpenseSortOption.lowestAmount,
        );

        notifier.clear();
        expect(container.read(expenseFilterProvider), ExpenseFilter.initial);
      },
    );

    test('ExpenseSearchQueryController sets and clears query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(expenseSearchQueryProvider.notifier);
      expect(container.read(expenseSearchQueryProvider), '');

      notifier.setQuery('coffee');
      expect(container.read(expenseSearchQueryProvider), 'coffee');

      notifier.clear();
      expect(container.read(expenseSearchQueryProvider), '');
    });

    test('filteredExpenseListProvider reactively updates with filters and search query', () async {
      final e1 = _createTestExpense(
        id: '1',
        title: 'Morning Coffee',
        amount: 5,
        category: ExpenseCategory.food,
      );
      final e2 = _createTestExpense(
        id: '2',
        title: 'Bus Ticket',
        amount: 3,
        category: ExpenseCategory.transport,
      );
      final e3 = _createTestExpense(
        id: '3',
        title: 'Afternoon Coffee',
        amount: 6,
        category: ExpenseCategory.food,
      );

      final container = ProviderContainer(
        overrides: [
          expenseListProvider.overrideWith((ref) => Stream.value([e1, e2, e3])),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(filteredExpenseListProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();

      expect(container.read(filteredExpenseListProvider).value?.length, 3);

      // Filter by food: 2 items
      container
          .read(expenseFilterProvider.notifier)
          .setCategory(ExpenseCategory.food);
      expect(container.read(filteredExpenseListProvider).value?.length, 2);

      // Search 'morning': 1 item
      container.read(expenseSearchQueryProvider.notifier).setQuery('morning');
      final filtered = container.read(filteredExpenseListProvider).value!;
      expect(filtered.length, 1);
      expect(filtered.single.title, 'Morning Coffee');

      // Clear search: back to 2 food items
      container.read(expenseSearchQueryProvider.notifier).clear();
      expect(container.read(filteredExpenseListProvider).value?.length, 2);

      // Clear filter: back to all 3
      container.read(expenseFilterProvider.notifier).clear();
      expect(container.read(filteredExpenseListProvider).value?.length, 3);
    });

    test('monthlyExpenseSummaryProvider derives total and counts for selected month', () async {
      final e1 = _createTestExpense(
        id: '1',
        title: 'Dinner',
        amount: 20,
        date: _thisMonth(5),
      );
      final e2 = _createTestExpense(
        id: '2',
        title: 'Lunch',
        amount: 15,
        date: _thisMonth(10),
      );
      final e3 = _createTestExpense(
        id: '3',
        title: 'Last month rent',
        amount: 500,
        date: MonthNavigation.previous(_now),
      );

      final container = ProviderContainer(
        overrides: [
          expenseListProvider.overrideWith((ref) => Stream.value([e1, e2, e3])),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(monthlyExpenseSummaryProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();

      final summary = container.read(monthlyExpenseSummaryProvider).value!;
      expect(summary.total, 35.0);
      expect(summary.transactionCount, 2);
      expect(summary.recentExpenses.length, 2);

      // Navigate to previous month
      container.read(selectedMonthProvider.notifier).previousMonth();
      final prevSummary = container.read(monthlyExpenseSummaryProvider).value!;
      expect(prevSummary.total, 500.0);
      expect(prevSummary.transactionCount, 1);
    });

    test(
      'monthlySpendingChartProvider recomputes 6-month historical trend',
      () async {
        final e1 = _createTestExpense(
          id: '1',
          title: 'Expense',
          amount: 100,
          date: _thisMonth(5),
        );
        final container = ProviderContainer(
          overrides: [
            expenseListProvider.overrideWith((ref) => Stream.value([e1])),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(monthlySpendingChartProvider, (_, _) {});
        addTearDown(sub.close);
        await pumpEventQueue();

        final points = container.read(monthlySpendingChartProvider).value!;
        expect(points.length, 6);
        expect(points.last.total, 100.0);
      },
    );
  });
}
