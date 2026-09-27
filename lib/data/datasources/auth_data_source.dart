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
}
