import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_spacing.dart';
import '../providers/auth_providers.dart';

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final action = ref.watch(authActionProvider);
    final controller = ref.read(authActionProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_unread_outlined, size: 56),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'Verify your email',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Text(
                    'We sent a verification link to ${user?.email ?? 'your email address'}. '
                    'Open the link, then return here to continue. Check your spam folder if it does not arrive.',
                    textAlign: TextAlign.center,
                  ),
                  if (action.hasError) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      authErrorMessage(action.error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.large),
                  FilledButton(
                    onPressed: action.isLoading ? null : controller.refreshUser,
                    child: const Text("I've verified my email"),
                  ),
                  const SizedBox(height: AppSpacing.small),
                  OutlinedButton(
                    onPressed: action.isLoading
                        ? null
                        : () async {
                            await controller.sendEmailVerification();
                            if (context.mounted &&
                                !ref.read(authActionProvider).hasError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Verification email sent.'),
                                ),
                              );
                            }
                          },
                    child: const Text('Resend verification email'),
                  ),
                  TextButton(
                    onPressed: action.isLoading ? null : controller.logout,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
