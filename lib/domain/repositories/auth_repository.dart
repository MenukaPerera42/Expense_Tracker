import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> watchUser();
  Future<void> login({required String email, required String password});
  Future<void> signInWithGoogle();
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> logout();
  Future<void> updateName(String name);

  /// Sends verification to the new address before changing it.
  Future<void> changeEmail({
    required String email,
    required String currentPassword,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> refreshUser();
  Future<void> sendEmailVerification();
}
