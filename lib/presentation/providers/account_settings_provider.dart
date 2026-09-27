import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

final accountSettingsProvider =
    NotifierProvider.autoDispose<AccountSettingsController, AsyncValue<void>>(
      AccountSettingsController.new,
    );

class AccountSettingsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<bool> updateName(String name) =>
      _run((repo) => repo.updateName(name.trim()));
  Future<bool> changeEmail(String email, String currentPassword) => _run(
    (repo) =>
        repo.changeEmail(email: email.trim(), currentPassword: currentPassword),
  );
  Future<bool> changePassword(String currentPassword, String newPassword) =>
      _run(
        (repo) => repo.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
  Future<bool> refreshUser() => _run((repo) => repo.refreshUser());

  Future<bool> _run(Future<void> Function(AuthRepository) operation) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      if (!ref.mounted) return false;
      await operation(repository);
      if (!ref.mounted) return false;
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(
          error is AppException
              ? error
              : const AppException(
                  AppErrorCode.unknown,
                  'Unable to update your account. Please try again.',
                ),
          stack,
        );
      }
      return false;
    }
  }
}
