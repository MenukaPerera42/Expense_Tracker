import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/firebase_error_mapper.dart';
import '../../core/errors/app_exception.dart';

/// SDK boundary. Feature repositories will map User into domain entities.
class AuthDataSource {
  AuthDataSource(this._auth, {Future<String?> Function()? googleIdToken})
    : _googleIdToken = googleIdToken ?? _getGoogleIdToken;
  final FirebaseAuth _auth;
  final Future<String?> Function() _googleIdToken;
  static Future<void>? _googleInitialization;

  static Future<String?> _getGoogleIdToken() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    try {
      await _googleInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppException(
          AppErrorCode.configuration,
          'Google sign-in is not configured. Please try again later.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw AppException(
        error.code == GoogleSignInExceptionCode.clientConfigurationError ||
                error.code ==
                    GoogleSignInExceptionCode.providerConfigurationError
            ? AppErrorCode.configuration
            : AppErrorCode.unknown,
        'Google sign-in is unavailable. Please try again.',
      );
    }
  }

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
  Future<UserCredential?> signInWithGoogle() async {
    final idToken = await _googleIdToken();
    if (idToken == null) return null; // The account picker was dismissed.
    if (idToken.isEmpty) {
      throw const AppException(
        AppErrorCode.configuration,
        'Google sign-in is not configured. Please try again later.',
      );
    }
    return FirebaseErrorMapper.guard(
      () => _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      ),
    );
  }

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

  Future<void> sendEmailVerification() => FirebaseErrorMapper.guard(() async {
    final user = _requireUser();
    if (!user.emailVerified) {
      await user.sendEmailVerification();
      _checkSession(user);
    }
  });
}
