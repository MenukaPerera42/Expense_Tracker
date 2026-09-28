import 'dart:async';

import 'package:flutter/material.dart';
import 'package:expense_tracker/presentation/widgets/category_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/config/currency_config.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';

/// In-memory fake implementation of [AuthRepository] to guarantee deterministic
/// tests without touching production Firebase Authentication.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _currentUser = initialUser {
    _controller = StreamController<AuthUser?>.broadcast(
      onListen: () => _controller.add(_currentUser),
    );
  }

  AuthUser? _currentUser;
  late final StreamController<AuthUser?> _controller;

  @override
  Stream<AuthUser?> watchUser() => _controller.stream;

  @override
  Future<void> login({required String email, required String password}) async {
    _currentUser = AuthUser(
      id: 'test-user-123',
      email: email,
      name: 'Test User',
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> signInWithGoogle() async {
    _currentUser = const AuthUser(
      id: 'test-google-user',
      email: 'google@example.com',
      name: 'Google User',
      hasPasswordProvider: false,
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _currentUser = AuthUser(id: 'test-user-123', email: email, name: name);
    _controller.add(_currentUser);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> updateName(String name) async {
    final user = _currentUser!;
    _currentUser = AuthUser(
      id: user.id,
      name: name.trim(),
      email: user.email,
      hasPasswordProvider: user.hasPasswordProvider,
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> changeEmail({
    required String email,
    required String currentPassword,
  }) async {}
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}
  @override
  Future<void> refreshUser() async => _controller.add(_currentUser);
  @override
  Future<void> sendEmailVerification() async {}

  void dispose() {
    _controller.close();
  }
}

/// In-memory fake implementation of [ExpenseRepository] to guarantee deterministic,
/// isolated storage without writing uncontrolled data to production Firestore.
class FakeExpenseRepository implements ExpenseRepository {
  FakeExpenseRepository() {
    _controller = StreamController<List<Expense>>.broadcast(
      onListen: () => _emit(),
    );
  }

  final Map<String, Expense> _expenses = {};
  late final StreamController<List<Expense>> _controller;
  int _idCounter = 1;

  void _emit() {
    final list = _expenses.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _controller.add(list);
  }

  @override
  String newExpenseId() => 'fake-exp-${_idCounter++}';

  @override
  Future<void> createExpense(Expense expense) async {
    _expenses[expense.id] = expense;
    _emit();
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    _expenses[expense.id] = expense;
    _emit();
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.remove(id);
    _emit();
  }

  @override
  Future<Expense?> getExpenseById(String id) async => _expenses[id];

  @override
  Future<List<Expense>> getExpenses({bool descending = true}) async {
    final list = _expenses.values.toList();
    list.sort(
      (a, b) =>
          descending ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );
    return list;
  }

  @override
  Stream<List<Expense>> watchExpenses({bool descending = true}) =>
      _controller.stream;

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('End-to-End Expense Tracker Flow', () {
    late FakeAuthRepository authRepo;
    late FakeExpenseRepository expenseRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authRepo = FakeAuthRepository();
      expenseRepo = FakeExpenseRepository();
    });

    tearDown(() {
      authRepo.dispose();
      expenseRepo.dispose();
    });

    testWidgets(
      'Full journey: register -> add expense -> view history -> edit -> filter -> delete -> dashboard total -> sign out',
      (tester) async {
        // Use a standard mobile viewport size
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appInitializerProvider.overrideWithValue(() async {}),
            authRepositoryProvider.overrideWith((ref) async => authRepo),
            expenseRepositoryProvider.overrideWith((ref) async => expenseRepo),
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

        // -------------------------------------------------------------
        // 1. Initial State: App redirects unauthenticated user to Login
        // -------------------------------------------------------------
        expect(find.text('Sign in'), findsWidgets);
        expect(find.text('Create an account'), findsOneWidget);

        // Switch to registration form
        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();

        expect(find.text('Create account'), findsWidgets);

        // Fill registration form
        final nameField = find.widgetWithText(TextFormField, 'Name');
        final emailField = find.widgetWithText(TextFormField, 'Email');
        final passwordField = find.widgetWithText(TextFormField, 'Password');
        final confirmPasswordField = find.widgetWithText(
          TextFormField,
          'Confirm password',
        );

        await tester.enterText(nameField, 'Jane Doe');
        await tester.enterText(emailField, 'jane@example.com');
        await tester.enterText(passwordField, 'Secret123!');
        await tester.enterText(confirmPasswordField, 'Secret123!');
        await tester.pumpAndSettle();

        // Submit registration
        final registerButton = find.widgetWithText(
          FilledButton,
          'Create account',
        );
        await tester.tap(registerButton);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // Verify authenticated arrival on Dashboard
        // -------------------------------------------------------------
        expect(find.text('Expense Tracker'), findsOneWidget);
        expect(find.textContaining('Jane Doe'), findsOneWidget);
        expect(find.textContaining('No expenses in'), findsOneWidget);

        // -------------------------------------------------------------
        // 2. Add Expense
        // -------------------------------------------------------------
        final addExpenseFab = find.byType(FloatingActionButton);
        expect(addExpenseFab, findsOneWidget);
        await tester.tap(addExpenseFab);
        await tester.pumpAndSettle();

        expect(find.text('Add expense'), findsOneWidget);

        // Enter title and amount
        final titleInput = find.widgetWithText(TextFormField, 'Title');
        final amountInput = find.widgetWithText(TextFormField, 'Amount');
        final noteInput = find.widgetWithText(TextFormField, 'Note (optional)');

        await tester.enterText(titleInput, 'Weekly Groceries');
        await tester.enterText(amountInput, '85.50');
        await tester.enterText(noteInput, 'Supermarket haul');

        // Select 'Food' category chip
        final foodChip = find.text('Food');
        await tester.ensureVisible(foodChip);
        await tester.tap(foodChip);
        await tester.pumpAndSettle();

        // Save expense
        final saveButton = find.widgetWithText(FilledButton, 'Save expense');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------
        // Verify Dashboard reflects newly added expense and total
        // -------------------------------------------------------------
        expect(
          find.text(CurrencyConfig.defaultCurrency.format(85.50)),
          findsWidgets,
        );
        expect(find.text('Weekly Groceries'), findsOneWidget);

        // -------------------------------------------------------------
        // 3. See Expense in History
        // -------------------------------------------------------------
        final viewAllButton = find.text('View all');
        await tester.ensureVisible(viewAllButton);
        await tester.tap(viewAllButton);
        await tester.pumpAndSettle();

        expect(find.text('All expenses'), findsOneWidget);
        expect(find.text('Weekly Groceries'), findsOneWidget);
        expect(
          find.text(CurrencyConfig.defaultCurrency.format(85.50)),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // 4. Edit Expense
        // -------------------------------------------------------------
        final editButton = find.byTooltip('Edit expense');
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(find.text('Edit expense'), findsOneWidget);

        // Update title to 'Organic Groceries' and amount to '125.00'
        final editTitleInput = find.widgetWithText(TextFormField, 'Title');
        final editAmountInput = find.widgetWithText(TextFormField, 'Amount');

        await tester.enterText(editTitleInput, 'Organic Groceries');
        await tester.enterText(editAmountInput, '125.00');

        final saveChangesButton = find.widgetWithText(
          FilledButton,
          'Save changes',
        );
        await tester.ensureVisible(saveChangesButton);
        await tester.tap(saveChangesButton);
        await tester.pumpAndSettle();

        // Back in Expense History, verify updated details
        expect(find.text('Organic Groceries'), findsOneWidget);
        expect(
          find.text(CurrencyConfig.defaultCurrency.format(125.00)),
          findsOneWidget,
        );

        // -------------------------------------------------------------
        // 5. Filter & Search Expenses
        // -------------------------------------------------------------
        // Test Category Filter
        final categoryFilterChip = find.text('Category');
        await tester.tap(categoryFilterChip);
        await tester.pumpAndSettle();

        // Select 'Transport' (which has 0 expenses)
        final transportOption = find.descendant(
          of: find.byType(CategoryPill),
          matching: find.text('Transport'),
        );
        await tester.tap(transportOption);
        await tester.pumpAndSettle();

        // Verify empty search/filter result state
        expect(find.text('No matching expenses'), findsOneWidget);

        // Clear filter using the action button in the empty status view
        final clearFilterButton = find.widgetWithText(
          FilledButton,
          'Clear filters',
        );
        await tester.tap(clearFilterButton);
        await tester.pumpAndSettle();

        // Verify expense is visible again
        expect(find.text('Organic Groceries'), findsOneWidget);

        // Test Search debounce
        final searchField = find.byType(TextField);
        await tester.enterText(searchField, 'Organic');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Organic Groceries'), findsOneWidget);

        await tester.enterText(searchField, 'NonExistent');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('No matching expenses'), findsOneWidget);

        // Clear search
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Organic Groceries'), findsOneWidget);

        // -------------------------------------------------------------
        // 6. Delete Expense
        // -------------------------------------------------------------
        final deleteButton = find.byTooltip('Delete expense');
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();

        // Confirm dialog
        expect(find.text('Delete expense?'), findsOneWidget);
        final confirmDeleteButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Delete'),
        );
        await tester.tap(confirmDeleteButton);
        await tester.pumpAndSettle();

        // Verify history is empty
        expect(find.text('No expenses yet'), findsOneWidget);

        // -------------------------------------------------------------
        // 7. Dashboard Total Changes Verified
        // -------------------------------------------------------------
        // Return to Dashboard
        final backButton = find.byTooltip('Back');
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton);
        } else {
          final navigator = Navigator.of(
            tester.element(find.byType(ExpenseTrackerApp)),
          );
          navigator.pop();
        }
        await tester.pumpAndSettle();

        // Verify dashboard is at $0.00 / empty month
        expect(find.textContaining('No expenses in'), findsOneWidget);

        // -------------------------------------------------------------
        // 8. Sign Out
        // -------------------------------------------------------------
        final signOutButton = find.byTooltip('Sign out');
        await tester.tap(signOutButton);
        await tester.pumpAndSettle();

        // Verify user is redirected back to Sign In
        expect(find.text('Sign in'), findsWidgets);
      },
    );
  });
}
