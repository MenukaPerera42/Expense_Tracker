import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/services/firebase_providers.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/entities/expense.dart';
import 'package:expense_tracker/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/domain/repositories/expense_repository.dart';
import 'package:expense_tracker/domain/usecases/auth_validation.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/routing/app_router.dart';

class MockRepository extends Mock implements AuthRepository {}

/// Trivial stand-in so Home's expense history stream has something to watch
/// without contacting Firebase; this file is about auth, not expenses.
class _EmptyExpenseRepository implements ExpenseRepository {
  @override
  Future<List<Expense>> getExpenses({bool descending = true}) async => [];
  @override
  Future<Expense?> getExpenseById(String id) async => null;
  @override
  Stream<List<Expense>> watchExpenses({bool descending = true}) =>
      Stream.value(const []);
  @override
  String newExpenseId() => 'unused';
  @override
  Future<void> createExpense(Expense expense) async {}
  @override
  Future<void> updateExpense(Expense expense) async {}
  @override
  Future<void> deleteExpense(String id) async {}
}

void main() {
  test(
    'email validation rejects malformed input and accepts trimmed addresses',
    () {
      for (final value in [
        '',
        'abc',
        'a@',
        'a b@example.com',
        'a@@example.com',
      ]) {
        expect(AuthValidation.email(value), isNotNull);
      }
      expect(AuthValidation.email(' alex+test@example.com '), isNull);
    },
  );
  test('password and confirmation validate without trimming credentials', () {
    expect(AuthValidation.password(''), isNotNull);
    expect(AuthValidation.password('12345'), isNotNull);
    expect(AuthValidation.password('123456'), isNotNull);
    for (final value in [
      'lowercase123!',
      'UPPERCASE123!',
      'NoNumber!',
      'NoSymbol123',
    ]) {
      expect(AuthValidation.password(value), isNotNull);
    }
    expect(AuthValidation.password('Secret123!'), isNull);
    expect(AuthValidation.loginPassword('oldpass'), isNull);
    expect(AuthValidation.confirmPassword('', 'secret'), isNotNull);
    expect(AuthValidation.confirmPassword('secret ', 'secret'), isNotNull);
    expect(AuthValidation.confirmPassword('secret', 'secret'), isNull);
    expect(AuthValidation.name('  '), isNotNull);
  });
  for (final operation in ['login', 'register', 'google', 'logout']) {
    for (final success in [true, false]) {
      test(
        '$operation ${success ? 'success' : 'failure'} exposes loading and completion',
        () async {
          final repo = MockRepository();
          final done = Completer<void>();
          when(() => repo.login(email: 'a@b.com', password: 'secret'))
              .thenAnswer((_) => done.future);
          when(
            () => repo.register(
              name: 'Alex',
              email: 'a@b.com',
              password: 'secret',
            ),
          ).thenAnswer((_) => done.future);
          when(repo.logout).thenAnswer((_) => done.future);
          when(repo.signInWithGoogle).thenAnswer((_) => done.future);
          final container = ProviderContainer(
            overrides: [
              authRepositoryProvider.overrideWith((ref) async => repo),
            ],
          );
          addTearDown(container.dispose);
          final controller = container.read(authActionProvider.notifier);
          final pending = switch (operation) {
            'login' => controller.login('a@b.com', 'secret'),
            'register' => controller.register('Alex', 'a@b.com', 'secret'),
            'google' => controller.signInWithGoogle(),
            _ => controller.logout(),
          };
          expect(container.read(authActionProvider).isLoading, isTrue);
          await container.read(authRepositoryProvider.future);
          if (success) {
            done.complete();
          } else {
            done.completeError(
              const AppException(
                AppErrorCode.network,
                'Check your connection.',
              ),
            );
          }
          await pending;
          expect(container.read(authActionProvider).isLoading, isFalse);
          expect(container.read(authActionProvider).hasError, !success);
        },
      );
    }
  }
  test(
    'unexpected errors are sanitized and duplicate submissions ignored',
    () async {
      final repo = MockRepository();
      final done = Completer<void>();
      when(() => repo.login(email: 'a', password: 'b'))
          .thenAnswer((_) => done.future);
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWith((ref) async => repo)],
      );
      addTearDown(container.dispose);
      final controller = container.read(authActionProvider.notifier);
      final first = controller.login('a', 'b');
      await controller.login('a', 'b');
      await container.read(authRepositoryProvider.future);
      done.completeError(StateError('raw private error'));
      await first;
      expect(
        authErrorMessage(container.read(authActionProvider).error),
        isNot(contains('raw private')),
      );
      verify(() => repo.login(email: 'a', password: 'b')).called(1);
    },
  );

  Future<ProviderContainer> mount(
    WidgetTester tester,
    MockRepository repo,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        appInitializerProvider.overrideWithValue(() async {}),
        authRepositoryProvider.overrideWith((ref) async => repo),
        expenseRepositoryProvider.overrideWith(
          (ref) async => _EmptyExpenseRepository(),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExpenseTrackerApp(),
      ),
    );
    return container;
  }

  testWidgets(
    'unresolved state hides home; sign in/out and errors update routes',
    (tester) async {
      final repo = MockRepository();
      final stream = StreamController<AuthUser?>();
      addTearDown(stream.close);
      when(repo.watchUser).thenAnswer((_) => stream.stream);
      final container = await mount(tester, repo);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      stream.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNWidgets(2));
      container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      stream.add(const AuthUser(id: 'one'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      container.read(appRouterProvider).go('/register');
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsNothing);
      stream.addError(StateError('private'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to start'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
    },
  );
  testWidgets(
    'restored session enters home and logout removes protected route',
    (tester) async {
      final repo = MockRepository();
      final stream = StreamController<AuthUser?>();
      addTearDown(stream.close);
      when(repo.watchUser).thenAnswer((_) => stream.stream);
      when(repo.logout).thenAnswer((_) async {
        stream.add(null);
      });
      final container = await mount(tester, repo);
      await tester.pump();
      stream.add(const AuthUser(id: 'restored'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      await container.read(authActionProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNWidgets(2));
      container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      verify(repo.logout).called(1);
    },
  );
  testWidgets('login form validates and shows safe failure with retry', (
    tester,
  ) async {
    final repo = MockRepository();
    when(repo.watchUser).thenAnswer((_) => Stream.value(null));
    when(() => repo.login(email: 'alex@example.com', password: 'secret'))
        .thenThrow(
          const AppException(
            AppErrorCode.invalidCredentials,
            'Unable to sign in with these credentials.',
          ),
        );
    await mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to sign in with these credentials.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
  testWidgets(
    'registration validates confirmation then submits name and credentials',
    (tester) async {
      final repo = MockRepository();
      when(repo.watchUser).thenAnswer((_) => Stream.value(null));
      when(
        () => repo.register(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'Secret123!',
        ),
      ).thenAnswer((_) async {});
      await mount(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      for (final entry in [
        'Alex',
        'alex@example.com',
        'Secret123!',
        'wrong',
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(fields.at(3), 'Secret123!');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      verify(
        () => repo.register(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'Secret123!',
        ),
      ).called(1);
    },
  );
  for (final register in [false, true]) {
    testWidgets(
      'Google button on ${register ? 'create account' : 'sign in'} bypasses form validation',
      (tester) async {
        final repo = MockRepository();
        when(repo.watchUser).thenAnswer((_) => Stream.value(null));
        when(repo.signInWithGoogle).thenAnswer((_) async {});
        await mount(tester, repo);
        await tester.pumpAndSettle();
        if (register) {
          await tester.tap(find.text('Create an account'));
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        verify(repo.signInWithGoogle).called(1);
        expect(find.text('Enter your email address.'), findsNothing);
      },
    );
  }
  testWidgets(
    'new password account stays on verification page until refreshed',
    (tester) async {
      final repo = MockRepository();
      final users = StreamController<AuthUser?>();
      addTearDown(users.close);
      when(repo.watchUser).thenAnswer((_) => users.stream);
      when(
        () => repo.register(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'Secret123!',
        ),
      ).thenAnswer((_) async {
        users.add(
          const AuthUser(
            id: 'new-user',
            email: 'alex@example.com',
            requiresEmailVerification: true,
          ),
        );
      });
      when(repo.sendEmailVerification).thenAnswer((_) async {});
      when(repo.refreshUser).thenAnswer((_) async {
        users.add(const AuthUser(id: 'new-user', email: 'alex@example.com'));
      });
      final container = await mount(tester, repo);
      users.add(null);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Alex');
      await tester.enterText(fields.at(1), 'alex@example.com');
      await tester.enterText(fields.at(2), 'Secret123!');
      await tester.enterText(fields.at(3), 'Secret123!');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      expect(find.text('Verify your email'), findsOneWidget);
      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      verify(repo.sendEmailVerification).called(1);
      await tester.tap(find.text("I've verified my email"));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );
}
