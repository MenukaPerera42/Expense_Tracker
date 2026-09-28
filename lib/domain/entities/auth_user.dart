class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.hasPasswordProvider = true,
    this.requiresEmailVerification = false,
  });
  final String id;
  final String? email;
  final String? name;
  final bool hasPasswordProvider;
  final bool requiresEmailVerification;
}
