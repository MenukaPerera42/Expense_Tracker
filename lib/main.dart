import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_initialization.dart';
import 'data/services/firebase_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      overrides: [
        appInitializerProvider.overrideWithValue(_initializeFirebase),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  try {
    await FirebaseServices.initialize();
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'expense_tracker',
        context: ErrorDescription('while initializing Firebase'),
      ),
    );
    rethrow;
  }
}
