enum AppErrorCode {
  unauthenticated,
  invalidCredentials,
  emailInUse,
  weakPassword,
  invalidEmail,
  network,
  permissionDenied,
  unavailable,
  rateLimited,
  notFound,
  configuration,
  unknown,
}

/// Safe to display; never contains the raw backend message or credentials.
class AppException implements Exception {
  const AppException(this.code, this.message);
  final AppErrorCode code;
  final String message;
  @override
  String toString() => 'AppException(${code.name}): $message';
}
