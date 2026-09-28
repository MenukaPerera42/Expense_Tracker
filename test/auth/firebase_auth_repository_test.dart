import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:expense_tracker/core/errors/app_exception.dart';
import 'package:expense_tracker/data/datasources/auth_data_source.dart';
import 'package:expense_tracker/data/repositories/firebase_auth_repository.dart';

class MockAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserInfo extends Mock implements UserInfo {}

class MockMetadata extends Mock implements UserMetadata {}

class MockCredential extends Mock implements UserCredential {}

void main() {
  setUpAll(() {
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback'));
  });
  late MockAuth auth;
  late MockUser user;
  late FirebaseAuthRepository repository;
  setUp(() {
    auth = MockAuth();
    user = MockUser();
    final metadata = MockMetadata();
    when(() => metadata.creationTime).thenReturn(DateTime.utc(2026, 9, 27));
    when(() => user.metadata).thenReturn(metadata);
    when(() => user.emailVerified).thenReturn(false);
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('id');
    when(() => user.sendEmailVerification()).thenAnswer((_) async {});
    final passwordProvider = MockUserInfo();
    when(() => passwordProvider.providerId).thenReturn('password');
    when(() => user.providerData).thenReturn([passwordProvider]);
    repository = FirebaseAuthRepository(AuthDataSource(auth));
    final credential = MockCredential();
    when(() => credential.user).thenReturn(user);
    when(
      () => auth.createUserWithEmailAndPassword(
        email: 'a@b.com',
        password: 'Secret123!',
      ),
    ).thenAnswer((_) async => credential);
    when(() => user.updateDisplayName('Alex')).thenAnswer((_) async {});
    when(auth.signOut).thenAnswer((_) async {});
  });
  test('registration persists trimmed name through Firebase profile', () async {
    await repository.register(
      name: ' Alex ',
      email: ' a@b.com ',
      password: 'Secret123!',
    );
    verify(() => user.updateDisplayName('Alex')).called(1);
    verify(() => user.sendEmailVerification()).called(1);
    verifyNever(auth.signOut);
  });
  test(
    'weak registration password is rejected before creating an account',
    () async {
      await expectLater(
        repository.register(name: 'Alex', email: 'a@b.com', password: 'secret'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            AppErrorCode.weakPassword,
          ),
        ),
      );
      verifyNever(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );
  test('Google sign-in passes an ID token to Firebase Auth', () async {
    final credential = MockCredential();
    when(() => auth.signInWithCredential(any()))
        .thenAnswer((_) async => credential);
    final googleRepository = FirebaseAuthRepository(
      AuthDataSource(auth, googleIdToken: () async => 'google-id-token'),
    );

    await googleRepository.signInWithGoogle();

    final firebaseCredential =
        verify(() => auth.signInWithCredential(captureAny())).captured.single
            as OAuthCredential;
    expect(firebaseCredential.providerId, 'google.com');
    expect(firebaseCredential.idToken, 'google-id-token');
  });
  test('dismissing Google sign-in does not call Firebase Auth', () async {
    final googleRepository = FirebaseAuthRepository(
      AuthDataSource(auth, googleIdToken: () async => null),
    );

    await googleRepository.signInWithGoogle();

    verifyNever(() => auth.signInWithCredential(any()));
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
        repository.register(
          name: 'Alex',
          email: 'a@b.com',
          password: 'Secret123!',
        ),
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
        password: 'Secret123!',
      ),
    ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
    await expectLater(
      repository.register(
        name: 'Alex',
        email: 'a@b.com',
        password: 'Secret123!',
      ),
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
      when(auth.userChanges)
          .thenAnswer((_) => Stream.fromIterable([user, null]));
      final events = await repository.watchUser().toList();
      expect(events.first!.id, 'id');
      expect(events.first!.name, 'Alex');
      expect(events.first!.hasPasswordProvider, isTrue);
      expect(events.last, isNull);
      await repository.logout();
      verify(auth.signOut).called(1);
    },
  );
  test('Google-only user has no password change option', () async {
    final googleProvider = MockUserInfo();
    when(() => googleProvider.providerId).thenReturn('google.com');
    when(() => user.providerData).thenReturn([googleProvider]);
    when(() => user.uid).thenReturn('google-id');
    when(auth.userChanges).thenAnswer((_) => Stream.value(user));

    final account = await repository.watchUser().first;

    expect(account!.hasPasswordProvider, isFalse);
  });
  test('new unverified password account requires verification', () async {
    final metadata = MockMetadata();
    when(() => metadata.creationTime).thenReturn(DateTime.utc(2026, 9, 29));
    when(() => user.metadata).thenReturn(metadata);
    when(auth.userChanges).thenAnswer((_) => Stream.value(user));

    expect(
      (await repository.watchUser().first)!.requiresEmailVerification,
      isTrue,
    );

    when(() => user.emailVerified).thenReturn(true);
    expect(
      (await repository.watchUser().first)!.requiresEmailVerification,
      isFalse,
    );
  });
  test('legacy unverified password account can still sign in', () async {
    when(auth.userChanges).thenAnswer((_) => Stream.value(user));
    expect(
      (await repository.watchUser().first)!.requiresEmailVerification,
      isFalse,
    );
  });
}
