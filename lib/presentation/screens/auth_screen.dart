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
                      if (action.hasError) ...[
                        const SizedBox(height: AppSpacing.medium),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            authErrorMessage(action.error),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
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
