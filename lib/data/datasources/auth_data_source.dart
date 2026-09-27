import 'package:firebase_auth/firebase_auth.dart';

import '../services/firebase_error_mapper.dart';
import '../../core/errors/app_exception.dart';

/// SDK boundary. Feature repositories will map User into domain entities.
class AuthDataSource {
  AuthDataSource(this._auth);
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() =>
      FirebaseErrorMapper.guardStream(_auth.authStateChanges);
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) => FirebaseErrorMapper.guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );
  Future<UserCredential> register({
    required String email,
    required String password,
  }) => FirebaseErrorMapper.guard(
    () => _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );
  Future<void> signOut() => FirebaseErrorMapper.guard(_auth.signOut);
  Future<void> registerWithName({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await register(email: email, password: password);
    try {
      final user = credential.user;
      if (user == null) throw StateError('Missing registered user');
      await FirebaseErrorMapper.guard(
        () => user.updateDisplayName(name.trim()),
      );
    } catch (_) {
      await signOut();
      throw const AppException(
        AppErrorCode.unknown,
        'Your account was created, but your name could not be saved. Please sign in.',
      );
    }
  }

  Future<void> resetPassword(String email) => FirebaseErrorMapper.guard(
    () => _auth.sendPasswordResetEmail(email: email.trim()),
  );
  Stream<User?> userChanges() =>
      FirebaseErrorMapper.guardStream(_auth.userChanges);

  User _requireUser() =>
      _auth.currentUser ??
      (throw const AppException(
        AppErrorCode.unauthenticated,
        'Please sign in again.',
      ));

  void _checkSession(User user) {
    if (_auth.currentUser?.uid != user.uid) {
      throw const AppException(
        AppErrorCode.unauthenticated,
        'Please sign in again.',
      );
    }
  }

  Future<void> updateName(String name) => FirebaseErrorMapper.guard(() async {
    final user = _requireUser();
    await user.updateDisplayName(name.trim());
    _checkSession(user);
  });

  Future<User> _reauthenticate(String password) async {
    final user = _requireUser();
    final email = user.email;
    if (email == null) {
      throw const AppException(
        AppErrorCode.invalidCredentials,
        'Sign in with an email and password to make this change.',
      );
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        throw const AppException(
          AppErrorCode.invalidCredentials,
          'Your current password is incorrect. Please try again.',
        );
      }
      rethrow;
    }
    _checkSession(user);
    return user;
  }

  Future<void> changeEmail({
    required String email,
    required String currentPassword,
  }) => FirebaseErrorMapper.guard(() async {
    final user = await _reauthenticate(currentPassword);
    await user.verifyBeforeUpdateEmail(email.trim());
    _checkSession(user);
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => FirebaseErrorMapper.guard(() async {
    final user = await _reauthenticate(currentPassword);
    await user.updatePassword(newPassword);
    _checkSession(user);
  });

  Future<void> refreshUser() => FirebaseErrorMapper.guard(() async {
    final user = _requireUser();
    await user.reload();
    _checkSession(user);
  });
}
