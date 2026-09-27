import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../domain/usecases/auth_validation.dart';
import '../providers/auth_providers.dart';

/// Shared form layout keeps validation, keyboard and loading behavior consistent.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.register = false});
  final bool register;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (ref.read(authActionProvider).isLoading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final actions = ref.read(authActionProvider.notifier);
    if (widget.register) {
      actions.register(_name.text.trim(), _email.text.trim(), _password.text);
    } else {
      actions.login(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authActionProvider);
    final title = widget.register ? 'Create account' : 'Sign in';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.large),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.large),
                      if (widget.register) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !action.isLoading,
                          decoration: const InputDecoration(labelText: 'Name'),
                          autofillHints: const [AutofillHints.name],
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: AuthValidation.name,
                        ),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      TextFormField(
                        controller: _email,
                        enabled: !action.isLoading,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: AuthValidation.email,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      TextFormField(
                        controller: _password,
                        enabled: !action.isLoading,
                        obscureText: _obscure,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          widget.register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: action.isLoading
                                ? null
                                : () => setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        textInputAction: widget.register
                            ? TextInputAction.next
                            : TextInputAction.done,
                        onFieldSubmitted: widget.register
                            ? null
                            : (_) => _submit(),
                        validator: AuthValidation.password,
                      ),
                      if (widget.register) ...[
                        const SizedBox(height: AppSpacing.medium),
                        TextFormField(
                          controller: _confirm,
                          enabled: !action.isLoading,
                          obscureText: _obscure,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) => AuthValidation.confirmPassword(
                            value,
                            _password.text,
                          ),
                        ),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: action.hasError
                            ? Padding(
                                key: const ValueKey('auth-error'),
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.medium,
                                ),
                                child: _AuthErrorBanner(
                                  message: authErrorMessage(action.error),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('auth-no-error'),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.large),
                      FilledButton(
                        onPressed: action.isLoading ? null : _submit,
                        child: action.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Please wait',
                                ),
                              )
                            : Text(title),
                      ),
                      TextButton(
                        onPressed: action.isLoading
                            ? null
                            : () {
                                ref
                                    .read(authActionProvider.notifier)
                                    .clearError();
                                context.go(
                                  widget.register ? '/login' : '/register',
                                );
                              },
                        child: Text(
                          widget.register
                              ? 'Already have an account? Sign in'
                              : 'Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A boxed, iconed error banner rather than plain colored text, so a failed
/// sign-in/registration reads as clearly as the confirmation dialogs and
/// SnackBars elsewhere in the app.
class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
