import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_data_source.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._source);
  final AuthDataSource _source;
  @override
  Stream<AuthUser?> watchUser() => _source.authStateChanges().map(
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
}
