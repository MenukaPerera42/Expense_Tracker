import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/auth_validation.dart';
import '../providers/account_settings_provider.dart';
import '../providers/auth_providers.dart';

enum AccountSetting { name, password }

class AccountSettingsTiles extends ConsumerWidget {
  const AccountSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final state = ref.watch(accountSettingsProvider);
    final enabled =
        user != null &&
        !state.isLoading &&
        !ref.watch(authActionProvider).isLoading;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Profile name'),
          subtitle: Text(user?.name ?? 'Set your name'),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled
              ? () => _edit(context, ref, user, AccountSetting.name)
              : null,
        ),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: const Text('Email address'),
          subtitle: Text(user?.email ?? 'Your sign-in email'),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          subtitle: const Text('Keep your account secure'),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled
              ? () => _edit(context, ref, user, AccountSetting.password)
              : null,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enabled
                ? () async {
                    final success = await ref
                        .read(accountSettingsProvider.notifier)
                        .refreshUser();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Profile refreshed.'
                              : authErrorMessage(
                                  ref.read(accountSettingsProvider).error,
                                ),
                        ),
                      ),
                    );
                  }
                : null,
            icon: state.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Refresh profile'),
          ),
        ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AuthUser user,
    AccountSetting setting,
  ) async {
    ref.read(accountSettingsProvider.notifier).clearError();
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => _AccountEditor(user: user, setting: setting),
    );
    if (!context.mounted || message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({required this.user, required this.setting});
  final AuthUser user;
  final AccountSetting setting;
  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _value;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();

  String get _title => switch (widget.setting) {
    AccountSetting.name => 'Edit profile name',
    AccountSetting.password => 'Change password',
  };

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.user.name);
  }

  @override
  void dispose() {
    _value.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(accountSettingsProvider).isLoading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final controller = ref.read(accountSettingsProvider.notifier);
    final success = await switch (widget.setting) {
      AccountSetting.name => controller.updateName(_value.text),
      AccountSetting.password => controller.changePassword(
        _currentPassword.text,
        _newPassword.text,
      ),
    };
    if (!mounted || !success) return;
    _currentPassword.clear();
    _newPassword.clear();
    _confirmation.clear();
    Navigator.of(context).pop(
      widget.setting == AccountSetting.name
          ? 'Profile name updated.'
          : 'Password updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountSettingsProvider);
    final saving = state.isLoading;
    final theme = Theme.of(context);
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                _title,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.setting == AccountSetting.name)
                        TextFormField(
                          controller: _value,
                          enabled: !saving,
                          decoration: const InputDecoration(
                            labelText: 'Profile name',
                          ),
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const [AutofillHints.name],
                          maxLength: 100,
                          validator: AuthValidation.name,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      if (widget.setting != AccountSetting.name) ...[
                        _PasswordField(
                          controller: _currentPassword,
                          label: 'Current password',
                          enabled: !saving,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your current password.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (widget.setting == AccountSetting.password) ...[
                        _PasswordField(
                          controller: _newPassword,
                          label: 'New password',
                          enabled: !saving,
                          newPassword: true,
                          validator: (value) =>
                              AuthValidation.password(value) ??
                              (value == _currentPassword.text
                                  ? 'Choose a different password.'
                                  : null),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: _confirmation,
                          label: 'Confirm new password',
                          enabled: !saving,
                          newPassword: true,
                          validator: (value) => AuthValidation.confirmPassword(
                            value,
                            _newPassword.text,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (state.hasError) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            authErrorMessage(state.error),
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: saving ? null : _submit,
                        child: saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  semanticsLabel: 'Saving changes',
                                ),
                              )
                            : const Text('Save changes'),
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

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.validator,
    this.newPassword = false,
  });
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final bool newPassword;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscure,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    textInputAction: TextInputAction.next,
    validator: widget.validator,
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: '${_obscure ? 'Show' : 'Hide'} ${widget.label.toLowerCase()}',
        onPressed: widget.enabled
            ? () => setState(() => _obscure = !_obscure)
            : null,
        icon: Icon(
          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
