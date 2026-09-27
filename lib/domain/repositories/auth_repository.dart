import '../entities/auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> watchUser();
  Future<void> login({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> logout();
}
