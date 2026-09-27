import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/services/firebase_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

final authRepositoryProvider = FutureProvider<AuthRepository>(
  (ref) async =>
      FirebaseAuthRepository(await ref.watch(authDataSourceProvider.future)),
);

final authStateProvider = StreamProvider<AuthUser?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchUser();
}, retry: (count, error) => null);

final authActionProvider = NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<void> login(String email, String password) =>
      _run((repo) => repo.login(email: email, password: password));
  Future<void> register(String name, String email, String password) => _run(
    (repo) => repo.register(name: name, email: email, password: password),
  );
  Future<void> logout() => _run((repo) => repo.logout());
  Future<void> _run(Future<void> Function(AuthRepository) action) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await action(await ref.read(authRepositoryProvider.future));
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(
        error is AppException
            ? error
            : const AppException(
                AppErrorCode.unknown,
                'Something went wrong. Please try again.',
              ),
        stack,
      );
    }
  }
}

String authErrorMessage(Object? error) => error is AppException
    ? error.message
    : 'Unable to access your account. Please try again.';
