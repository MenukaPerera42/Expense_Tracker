import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supplied by main so the UI and tests never initialize Firebase directly.
final appInitializerProvider = Provider<Future<void> Function()>((ref) {
  throw StateError('An app initializer must be supplied at the entry point.');
});

final appInitializationProvider = FutureProvider<void>(
  (ref) => ref.watch(appInitializerProvider)(),
  // Startup failures require the visible Retry action, not background retries.
  retry: (retryCount, error) => null,
);
