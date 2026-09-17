class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.status,
  });

  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? status;

  String get displayName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return email;
    return parts.join(' ');
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      phone: json['phone']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.refreshExpiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int? expiresIn;
  final int? refreshExpiresIn;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      expiresIn: _asInt(json['expires_in']),
      refreshExpiresIn: _asInt(json['refresh_expires_in']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.tokens,
  });

  final AuthUser user;
  final AuthTokens tokens;
}

sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess(this.session);
  final AuthSession session;
}

class LoginMfaRequired extends LoginResult {
  const LoginMfaRequired(this.challengeToken);
  final String challengeToken;
}

sealed class RegisterResult {
  const RegisterResult();
}

class RegisterSuccess extends RegisterResult {
  const RegisterSuccess(this.session);
  final AuthSession session;
}

class RegisterEmailVerificationRequired extends RegisterResult {
  const RegisterEmailVerificationRequired({
    required this.email,
    this.message =
        'Check your email to verify your account, then sign in.',
  });

  final String email;
  final String message;
}

class PhoneOtpConfirmResult {
  const PhoneOtpConfirmResult({
    required this.phoneVerificationToken,
    required this.phone,
    this.expiresIn,
  });

  final String phoneVerificationToken;
  final String phone;
  final int? expiresIn;
}

class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.phoneVerificationToken,
    required this.password,
    required this.passwordConfirmation,
    required this.acceptTerms,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String phoneVerificationToken;
  final String password;
  final String passwordConfirmation;
  final bool acceptTerms;
}

/// Client-side password strength check mirroring backend RegisterRequest.
String? validateRegisterPassword(String password) {
  if (password.length < 8) {
    return 'Use at least 8 characters';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Include at least one uppercase letter';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Include at least one lowercase letter';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Include at least one number';
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'Include at least one special character';
  }
  return null;
}

