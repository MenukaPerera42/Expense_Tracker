import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_validation.dart';
import '../datasources/auth_data_source.dart';

// Existing password accounts remain usable. Keep this UTC cutoff fixed after
// rollout so future unverified registrations cannot become legacy accounts.
final DateTime _verificationRollout = DateTime.utc(2026, 9, 28, 6, 31, 21);

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._source);
  final AuthDataSource _source;
  @override
  Stream<AuthUser?> watchUser() =>
      _source.userChanges().map((user) => user == null ? null : _mapUser(user));

  AuthUser _mapUser(User user) {
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    return AuthUser(
      id: user.uid,
      email: user.email,
      name: user.displayName,
      hasPasswordProvider: hasPasswordProvider,
      requiresEmailVerification: _requiresVerification(
        user,
        hasPasswordProvider,
      ),
    );
  }

  bool _requiresVerification(User user, bool hasPasswordProvider) {
    if (!hasPasswordProvider || user.emailVerified) return false;
    final created = user.metadata.creationTime;
    return created == null || !created.toUtc().isBefore(_verificationRollout);
  }

  @override
  Future<void> login({required String email, required String password}) async {
    await _source.signIn(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() async {
    await _source.signInWithGoogle();
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final passwordError = AuthValidation.password(password);
    if (passwordError != null) {
      throw AppException(AppErrorCode.weakPassword, passwordError);
    }
    await _source.registerWithName(
      name: name,
      email: email,
      password: password,
    );
    await _source.sendEmailVerification();
  }

  @override
  Future<void> logout() => _source.signOut();
  @override
  Future<void> updateName(String name) => _source.updateName(name);
  @override
  Future<void> changeEmail({
    required String email,
    required String currentPassword,
  }) => _source.changeEmail(email: email, currentPassword: currentPassword);
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordError = AuthValidation.password(newPassword);
    if (passwordError != null) {
      throw AppException(AppErrorCode.weakPassword, passwordError);
    }
    await _source.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<void> refreshUser() => _source.refreshUser();
  @override
  Future<void> sendEmailVerification() => _source.sendEmailVerification();
}
