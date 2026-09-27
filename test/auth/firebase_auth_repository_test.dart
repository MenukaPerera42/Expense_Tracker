import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/datasources/auth_data_source.dart';
import 'package:expense_tracker/data/repositories/firebase_auth_repository.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockCredential extends Mock implements UserCredential {}

void main() {
  late MockAuth auth;
  late MockUser user;
  late FirebaseAuthRepository repository;
  setUp(() {
    auth = MockAuth();
    user = MockUser();
    repository = FirebaseAuthRepository(AuthDataSource(auth));
    final credential = MockCredential();
    when(() => credential.user).thenReturn(user);
    when(
      () => auth.createUserWithEmailAndPassword(
        email: 'a@b.com',
        password: 'secret',
      ),
    ).thenAnswer((_) async => credential);
    when(() => user.updateDisplayName('Alex')).thenAnswer((_) async {});
    when(auth.signOut).thenAnswer((_) async {});
  });
  test('registration persists trimmed name through Firebase profile', () async {
    await repository.register(
      name: ' Alex ',
      email: ' a@b.com ',
      password: 'secret',
    );
    verify(() => user.updateDisplayName('Alex')).called(1);
    verifyNever(auth.signOut);
  });
  test(
    'profile failure signs out and reports partial account creation safely',
    () async {
      when(() => user.updateDisplayName('Alex')).thenThrow(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'raw details',
        ),
      );
      await expectLater(
        repository.register(name: 'Alex', email: 'a@b.com', password: 'secret'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('account was created'),
          ),
        ),
      );
      verify(auth.signOut).called(1);
    },
  );
  test('registration rejection does not try to update a profile', () async {
    when(
      () => auth.createUserWithEmailAndPassword(
        email: 'a@b.com',
        password: 'secret',
      ),
    ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
    await expectLater(
      repository.register(name: 'Alex', email: 'a@b.com', password: 'secret'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.emailInUse,
        ),
      ),
    );
    verifyNever(() => user.updateDisplayName(any()));
  });
  test(
    'repository maps restored user and logout events to domain values',
    () async {
      when(() => user.uid).thenReturn('id');
      when(() => user.email).thenReturn('a@b.com');
      when(() => user.displayName).thenReturn('Alex');
      when(auth.authStateChanges)
          .thenAnswer((_) => Stream.fromIterable([user, null]));
      final events = await repository.watchUser().toList();
      expect(events.first!.id, 'id');
      expect(events.first!.name, 'Alex');
      expect(events.last, isNull);
      await repository.logout();
      verify(auth.signOut).called(1);
    },
  );
}
