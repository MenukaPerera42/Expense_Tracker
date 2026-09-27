import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/datasources/auth_data_source.dart';
import 'package:expense_tracker/data/repositories/firebase_auth_repository.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Credential extends Mock implements UserCredential {}

void main() {
  late _Auth auth;
  late _User user;
  late FirebaseAuthRepository repository;
  setUpAll(
    () => registerFallbackValue(
      EmailAuthProvider.credential(
        email: 'old@example.com',
        password: 'old-password',
      ),
    ),
  );
  setUp(() {
    auth = _Auth();
    user = _User();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('u');
    when(() => user.email).thenReturn('old@example.com');
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((_) async => _Credential());
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => user.verifyBeforeUpdateEmail(any())).thenAnswer((_) async {});
    when(() => user.updatePassword(any())).thenAnswer((_) async {});
    when(() => user.reload()).thenAnswer((_) async {});
    repository = FirebaseAuthRepository(AuthDataSource(auth));
  });

  test('name is trimmed and updated without reauthentication', () async {
    await repository.updateName(' Alex Smith ');
    verify(() => user.updateDisplayName('Alex Smith')).called(1);
    verifyNever(() => user.reauthenticateWithCredential(any()));
  });

  test('email verification waits for successful reauthentication', () async {
    final gate = Completer<UserCredential>();
    when(() => user.reauthenticateWithCredential(any()))
        .thenAnswer((_) => gate.future);
    final pending = repository.changeEmail(
      email: ' new@gmail.com ',
      currentPassword: ' old password ',
    );
    await pumpEventQueue();
    verifyNever(() => user.verifyBeforeUpdateEmail(any()));
    gate.complete(_Credential());
    await pending;
    final credential =
        verify(() => user.reauthenticateWithCredential(captureAny()))
                .captured
                .single
            as EmailAuthCredential;
    expect(credential.email, 'old@example.com');
    expect(credential.password, ' old password ');
    verify(() => user.verifyBeforeUpdateEmail('new@gmail.com')).called(1);
  });

  test('password is updated after reauthentication without trimming', () async {
    await repository.changePassword(
      currentPassword: 'old-password',
      newPassword: ' new password ',
    );
    verifyInOrder([
      () => user.reauthenticateWithCredential(any()),
      () => user.updatePassword(' new password '),
    ]);
  });

  test(
    'wrong password does not request email verification or update password',
    () async {
      when(() => user.reauthenticateWithCredential(any())).thenThrow(
        FirebaseAuthException(
          code: 'invalid-credential',
          message: 'raw sensitive error',
        ),
      );
      for (final operation in [
        () => repository.changeEmail(
          email: 'new@gmail.com',
          currentPassword: 'wrong',
        ),
        () => repository.changePassword(
          currentPassword: 'wrong',
          newPassword: 'new-password',
        ),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<AppException>()
                .having((e) => e.code, 'code', AppErrorCode.invalidCredentials)
                .having(
                  (e) => e.message,
                  'message',
                  'Your current password is incorrect. Please try again.',
                ),
          ),
        );
      }
      verifyNever(() => user.verifyBeforeUpdateEmail(any()));
      verifyNever(() => user.updatePassword(any()));
    },
  );

  test('session change during reauthentication prevents the update', () async {
    when(() => user.reauthenticateWithCredential(any())).thenAnswer((_) async {
      when(() => auth.currentUser).thenReturn(null);
      return _Credential();
    });
    await expectLater(
      repository.changePassword(
        currentPassword: 'old',
        newPassword: 'new-password',
      ),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.unauthenticated,
        ),
      ),
    );
    verifyNever(() => user.updatePassword(any()));
  });

  test('signed-out updates fail without SDK writes', () async {
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(
      repository.updateName('Alex'),
      throwsA(isA<AppException>()),
    );
    verifyNever(() => user.updateDisplayName(any()));
  });

  test('Firebase rejection maps to a safe account error', () async {
    when(() => user.verifyBeforeUpdateEmail(any()))
        .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
    await expectLater(
      repository.changeEmail(email: 'taken@gmail.com', currentPassword: 'old'),
      throwsA(
        isA<AppException>().having(
          (e) => e.code,
          'code',
          AppErrorCode.emailInUse,
        ),
      ),
    );
  });

  test('refresh reloads externally verified account data', () async {
    await repository.refreshUser();
    verify(() => user.reload()).called(1);
  });

  test(
    'profile changes reach watchers even when the user ID is unchanged',
    () async {
      final updated = _User();
      when(() => user.displayName).thenReturn('Before');
      when(() => updated.uid).thenReturn('u');
      when(() => updated.email).thenReturn('new@gmail.com');
      when(() => updated.displayName).thenReturn('After');
      when(auth.userChanges)
          .thenAnswer((_) => Stream.fromIterable([user, updated]));
      final events = await repository.watchUser().toList();
      expect(events.map((e) => e!.name), ['Before', 'After']);
      expect(events.last!.email, 'new@gmail.com');
      expect(events.first!.id, events.last!.id);
    },
  );
}
