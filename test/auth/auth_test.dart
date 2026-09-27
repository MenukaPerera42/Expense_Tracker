import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/app.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/domain/entities/auth_user.dart';
import 'package:expense_tracker/domain/repositories/auth_repository.dart';
import 'package:expense_tracker/domain/usecases/auth_validation.dart';
import 'package:expense_tracker/data/app_initialization.dart';
import 'package:expense_tracker/presentation/providers/auth_providers.dart';
import 'package:expense_tracker/routing/app_router.dart';

class MockRepository extends Mock implements AuthRepository {}

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
    expect(AuthValidation.password('123456'), isNull);
    expect(AuthValidation.confirmPassword('', 'secret'), isNotNull);
    expect(AuthValidation.confirmPassword('secret ', 'secret'), isNotNull);
    expect(AuthValidation.confirmPassword('secret', 'secret'), isNull);
    expect(AuthValidation.name('  '), isNotNull);
  });
  for (final operation in ['login', 'register', 'logout']) {
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
    final container = ProviderContainer(
      overrides: [
        appInitializerProvider.overrideWithValue(() async {}),
        authRepositoryProvider.overrideWith((ref) async => repo),
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
      expect(find.text('A clearer view of your spending'), findsNothing);
      stream.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNWidgets(2));
      container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('A clearer view of your spending'), findsNothing);
      stream.add(const AuthUser(id: 'one'));
      await tester.pumpAndSettle();
      expect(find.text('A clearer view of your spending'), findsOneWidget);
      container.read(appRouterProvider).go('/register');
      await tester.pumpAndSettle();
      expect(find.text('Create account'), findsNothing);
      stream.addError(StateError('private'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to start'), findsOneWidget);
      expect(find.text('A clearer view of your spending'), findsNothing);
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
      expect(find.byTooltip('Sign out'), findsOneWidget);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNWidgets(2));
      container.read(appRouterProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sign out'), findsNothing);
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
          password: 'secret',
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
        'secret',
        'wrong',
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await tester.enterText(fields.at(3), 'secret');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      verify(
        () => repo.register(
          name: 'Alex',
          email: 'alex@example.com',
          password: 'secret',
        ),
      ).called(1);
    },
  );
}
