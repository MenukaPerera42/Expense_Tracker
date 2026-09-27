import 'package:flutter/foundation.dart';

class FirebaseEnvironment {
  const FirebaseEnvironment({
    this.useEmulators = false,
    this.host = '10.0.2.2',
  });
  static const current = FirebaseEnvironment(
    useEmulators: bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    host: String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    ),
  );
  final bool useEmulators;
  final String host;
  static const authPort = 9099;
  static const firestorePort = 8080;

  void validate({bool releaseMode = kReleaseMode}) {
    if (useEmulators && releaseMode) {
      throw StateError('Firebase emulators are not allowed in release builds.');
    }
    if (useEmulators &&
        (host.trim().isEmpty || host.contains('://') || host.contains('/'))) {
      throw ArgumentError(
        'Provide an emulator hostname without a scheme or path.',
      );
    }
  }
}
