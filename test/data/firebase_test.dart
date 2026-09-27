import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/core/config/firebase_environment.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/services/firebase_error_mapper.dart';
import 'package:expense_tracker/data/datasources/auth_data_source.dart';
import 'package:expense_tracker/data/datasources/firestore_data_source.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCredential extends Mock implements UserCredential {}

class MockFirestore extends Mock implements FirebaseFirestore {}

// Mock-only SDK boundary; no production subclassing of sealed SDK types.
// ignore: subtype_of_sealed_class
class MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

Matcher failure(AppErrorCode code) =>
    isA<AppException>().having((e) => e.code, 'code', code);

void main() {
  test('Firebase codes map to safe application errors without raw details', () {
    final codes = {
      'invalid-credential': AppErrorCode.invalidCredentials,
      'wrong-password': AppErrorCode.invalidCredentials,
      'user-not-found': AppErrorCode.invalidCredentials,
      'email-already-in-use': AppErrorCode.emailInUse,
      'weak-password': AppErrorCode.weakPassword,
      'invalid-email': AppErrorCode.invalidEmail,
      'network-request-failed': AppErrorCode.network,
      'permission-denied': AppErrorCode.permissionDenied,
      'unauthenticated': AppErrorCode.unauthenticated,
      'requires-recent-login': AppErrorCode.unauthenticated,
      'unavailable': AppErrorCode.unavailable,
      'too-many-requests': AppErrorCode.rateLimited,
      'not-found': AppErrorCode.notFound,
      'operation-not-allowed': AppErrorCode.configuration,
      'new-code': AppErrorCode.unknown,
    };
    for (final entry in codes.entries) {
      final mapped = FirebaseErrorMapper.map(
        FirebaseException(
          plugin: 'test',
          code: entry.key,
          message: 'private backend details',
        ),
      );
      expect(mapped.code, entry.value);
      expect(mapped.toString(), isNot(contains('private backend details')));
    }
  });
  test('unexpected programming errors are not hidden by the mapper', () async {
    await expectLater(
      FirebaseErrorMapper.guard(() async => throw StateError('bug')),
      throwsStateError,
    );
  });
  test('emulator configuration rejects release use and malformed hosts', () {
    expect(
      () =>
          const FirebaseEnvironment(useEmulators: true)
              .validate(releaseMode: true),
      throwsStateError,
    );
    expect(
      () => const FirebaseEnvironment(
        useEmulators: true,
        host: 'http://localhost',
      ).validate(releaseMode: false),
      throwsArgumentError,
    );
    const FirebaseEnvironment(useEmulators: true).validate(releaseMode: false);
  });

  group('Auth data source', () {
    late MockAuth auth;
    late AuthDataSource source;
    setUp(() {
      auth = MockAuth();
      source = AuthDataSource(auth);
    });
    test(
      'sign in trims email but preserves password and returns credential',
      () async {
        final credential = MockCredential();
        when(
          () => auth.signInWithEmailAndPassword(
            email: 'a@example.com',
            password: ' secret ',
          ),
        ).thenAnswer((_) async => credential);
        expect(
          await source.signIn(email: ' a@example.com ', password: ' secret '),
          same(credential),
        );
      },
    );
    test('registration, reset and sign out delegate to injected SDK', () async {
      final credential = MockCredential();
      when(
        () => auth.createUserWithEmailAndPassword(
          email: 'a@example.com',
          password: 'secret',
        ),
      ).thenAnswer((_) async => credential);
      when(() => auth.sendPasswordResetEmail(email: 'a@example.com'))
          .thenAnswer((_) async {});
      when(auth.signOut).thenAnswer((_) async {});
      expect(
        await source.register(email: ' a@example.com ', password: 'secret'),
        same(credential),
      );
      await source.resetPassword(' a@example.com ');
      await source.signOut();
      verify(() => auth.sendPasswordResetEmail(email: 'a@example.com'))
          .called(1);
      verify(auth.signOut).called(1);
    });
    test('sign in errors are mapped', () async {
      when(() => auth.signInWithEmailAndPassword(email: 'a', password: 'b'))
          .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
      await expectLater(
        source.signIn(email: 'a', password: 'b'),
        throwsA(failure(AppErrorCode.invalidCredentials)),
      );
    });
    test('auth stream emits sign in/sign out and maps errors', () async {
      final user = MockUser();
      when(auth.authStateChanges)
          .thenAnswer((_) => Stream<User?>.fromIterable([user, null]));
      await expectLater(
        source.authStateChanges(),
        emitsInOrder([user, null, emitsDone]),
      );
      when(auth.authStateChanges).thenAnswer(
        (_) => Stream<User?>.error(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
      );
      await expectLater(
        source.authStateChanges(),
        emitsError(failure(AppErrorCode.network)),
      );
    });
  });

  group('Firestore data source', () {
    late MockAuth auth;
    late MockFirestore firestore;
    late MockDocument expense;
    late MockSnapshot snapshot;
    late FirestoreDataSource source;
    setUp(() {
      auth = MockAuth();
      firestore = MockFirestore();
      expense = MockDocument();
      snapshot = MockSnapshot();
      final user = MockUser();
      final users = MockCollection();
      final userDoc = MockDocument();
      final expenses = MockCollection();
      when(() => user.uid).thenReturn('owner');
      when(() => auth.currentUser).thenReturn(user);
      when(() => firestore.collection('users')).thenReturn(users);
      when(() => users.doc('owner')).thenReturn(userDoc);
      when(() => userDoc.collection('expenses')).thenReturn(expenses);
      when(() => expenses.doc('expense')).thenReturn(expense);
      when(() => expense.get()).thenAnswer((_) async => snapshot);
      source = FirestoreDataSource(firestore, auth);
    });
    test(
      'reads only the signed-in owner path and supports missing documents',
      () async {
        when(snapshot.data).thenReturn({'title': 'Lunch'});
        expect(await source.getExpense('expense'), {'title': 'Lunch'});
        when(snapshot.data).thenReturn(null);
        expect(await source.getExpense('expense'), isNull);
        verify(() => expense.get()).called(2);
      },
    );
    test(
      'signed-out access and path injection fail before database access',
      () async {
        when(() => auth.currentUser).thenReturn(null);
        await expectLater(
          source.getExpense('expense'),
          throwsA(failure(AppErrorCode.unauthenticated)),
        );
        await expectLater(source.getExpense('../other'), throwsArgumentError);
        verifyNever(() => firestore.collection(any()));
      },
    );
    test('permission errors are mapped', () async {
      when(() => expense.get()).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await expectLater(
        source.getExpense('expense'),
        throwsA(failure(AppErrorCode.permissionDenied)),
      );
    });
    test('in-flight results are rejected after sign out', () async {
      final pending = Completer<DocumentSnapshot<Map<String, dynamic>>>();
      when(() => expense.get()).thenAnswer((_) => pending.future);
      final result = source.getExpense('expense');
      when(() => auth.currentUser).thenReturn(null);
      pending.complete(snapshot);
      await expectLater(result, throwsA(failure(AppErrorCode.unauthenticated)));
    });
  });
}
