import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/config/firebase_environment.dart';
import '../../firebase_options.dart';

abstract final class FirebaseServices {
  static Future<void> initialize({
    FirebaseEnvironment environment = FirebaseEnvironment.current,
  }) async {
    environment.validate();
    final app = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          )
        : Firebase.app();
    if (environment.useEmulators) {
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      await auth.useAuthEmulator(
        environment.host,
        FirebaseEnvironment.authPort,
      );
      firestore.settings = const Settings(persistenceEnabled: false);
      firestore.useFirestoreEmulator(
        environment.host,
        FirebaseEnvironment.firestorePort,
      );
    }
  }
}
