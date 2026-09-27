import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._source);
  final AuthDataSource _source;
  @override
  Stream<AuthUser?> watchUser() => _source.userChanges().map(
    (user) => user == null
        ? null
        : AuthUser(id: user.uid, email: user.email, name: user.displayName),
  );
  @override
  Future<void> login({required String email, required String password}) async {
    await _source.signIn(email: email, password: password);
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _source.registerWithName(
      name: name,
      email: email,
      password: password,
    );
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
  }) => _source.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );
  @override
  Future<void> refreshUser() => _source.refreshUser();
}
