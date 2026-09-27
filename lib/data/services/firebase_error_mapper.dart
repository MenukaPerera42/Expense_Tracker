import 'package:firebase_core/firebase_core.dart';

import '../../core/errors/app_exception.dart';

abstract final class FirebaseErrorMapper {
  static AppException map(FirebaseException error) => switch (error.code) {
    'already-exists' || 'aborted' => const AppException(
      AppErrorCode.conflict,
      'This expense changed. Refresh and try again.',
    ),
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'user-disabled' => const AppException(
      AppErrorCode.invalidCredentials,
      'Unable to sign in with these credentials.',
    ),
    'email-already-in-use' => const AppException(
      AppErrorCode.emailInUse,
      'This email is already in use.',
    ),
    'weak-password' => const AppException(
      AppErrorCode.weakPassword,
      'Choose a stronger password.',
    ),
    'invalid-email' => const AppException(
      AppErrorCode.invalidEmail,
      'Enter a valid email address.',
    ),
    'network-request-failed' => const AppException(
      AppErrorCode.network,
      'Check your connection and try again.',
    ),
    'permission-denied' => const AppException(
      AppErrorCode.permissionDenied,
      'You do not have permission to access this data.',
    ),
    'unauthenticated' || 'requires-recent-login' => const AppException(
      AppErrorCode.unauthenticated,
      'Please sign in again.',
    ),
    'unavailable' || 'deadline-exceeded' => const AppException(
      AppErrorCode.unavailable,
      'The service is temporarily unavailable. Try again.',
    ),
    'too-many-requests' || 'resource-exhausted' => const AppException(
      AppErrorCode.rateLimited,
      'Too many requests. Please try again later.',
    ),
    'not-found' => const AppException(
      AppErrorCode.notFound,
      'The requested data was not found.',
    ),
    'operation-not-allowed' ||
    'invalid-api-key' ||
    'app-not-authorized' => const AppException(
      AppErrorCode.configuration,
      'The service is not configured for this operation.',
    ),
    _ => const AppException(
      AppErrorCode.unknown,
      'Something went wrong. Please try again.',
    ),
  };

  static Future<T> guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FirebaseException catch (error, stack) {
      Error.throwWithStackTrace(map(error), stack);
    }
  }

  static Stream<T> guardStream<T>(Stream<T> Function() operation) async* {
    try {
      yield* operation().handleError((Object error, StackTrace stack) {
        if (error is FirebaseException) {
          Error.throwWithStackTrace(map(error), stack);
        }
        Error.throwWithStackTrace(error, stack);
      });
    } on FirebaseException catch (error, stack) {
      Error.throwWithStackTrace(map(error), stack);
    }
  }
}
