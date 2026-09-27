import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_initialization.dart';
import '../../data/services/firebase_providers.dart';
import '../providers/auth_providers.dart';
import '../widgets/status_view.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appInitializationProvider);
    final auth = ref.watch(authStateProvider);
    final failed = startup.hasError || auth.hasError;
    return Scaffold(
      body: SafeArea(
        child: failed
            ? StatusView(
                icon: Icons.cloud_off_outlined,
                title: 'Unable to start',
                message: authErrorMessage(startup.error ?? auth.error),
                action: FilledButton(
                  onPressed: () {
                    ref.invalidate(appInitializationProvider);
                    ref.invalidate(firebaseAuthProvider);
                    ref.invalidate(authRepositoryProvider);
                    ref.invalidate(authStateProvider);
                  },
                  child: const Text('Retry'),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Restoring your session',
                ),
              ),
      ),
    );
  }
}
