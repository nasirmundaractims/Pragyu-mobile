import 'dart:convert';

import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';

abstract class AuthGateway {
  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  });

  Future<AuthSession> verifyMfaLogin({
    required String challengeToken,
    required String code,
  });

  /// Requests a reset email. API always succeeds (no account enumeration).
  Future<void> forgotPassword({required String email});

  Future<void> requestRegistrationPhoneOtp({required String phone});

  Future<PhoneOtpConfirmResult> confirmRegistrationPhoneOtp({
    required String phone,
    required String code,
  });

  Future<RegisterResult> register(RegisterRequest request);

  Future<void> clearSession();
}

class AuthRepository implements AuthGateway {
  AuthRepository({
    ApiClient? apiClient,
    TokenStore? tokenStore,
  })  : _api = apiClient ?? ApiClient(),
        _tokens = tokenStore ?? createTokenStore();

  static const deviceName = 'pragyu-student-mobile';

  final ApiClient _api;
  final TokenStore _tokens;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final envelope = await _api.post(
      '/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': deviceName,
        'remember_me': rememberMe,
      },
    );

    final data = _asJsonMap(envelope['data']);
    if (data['mfa_required'] == true) {
      final challenge = data['mfa_challenge_token']?.toString() ?? '';
      if (challenge.isEmpty) {
        throw StateError('MFA required but challenge token missing.');
      }
      return LoginMfaRequired(challenge);
    }

    final session = _sessionFromData(data);
    await _persist(session);
    return LoginSuccess(session);
  }

  @override
  Future<AuthSession> verifyMfaLogin({
    required String challengeToken,
    required String code,
  }) async {
    final envelope = await _api.post(
      '/auth/mfa/verify-login',
      body: {
        'mfa_challenge_token': challengeToken,
        'code': code.trim(),
        'device_name': deviceName,
      },
    );
    final data = _asJsonMap(envelope['data']);
    final session = _sessionFromData(data);
    await _persist(session);
    return session;
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await _api.post(
      '/auth/forgot-password',
      body: {'email': email.trim()},
    );
  }

  @override
  Future<void> requestRegistrationPhoneOtp({required String phone}) async {
    await _api.post(
      '/auth/register/phone/request-otp',
      body: {'phone': phone.trim()},
    );
  }

  @override
  Future<PhoneOtpConfirmResult> confirmRegistrationPhoneOtp({
    required String phone,
    required String code,
  }) async {
    final envelope = await _api.post(
      '/auth/register/phone/confirm',
      body: {
        'phone': phone.trim(),
        'code': code.trim(),
      },
    );
    final data = _asJsonMap(envelope['data']);
    final token = data['phone_verification_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw StateError('Phone verification token missing.');
    }
    return PhoneOtpConfirmResult(
      phoneVerificationToken: token,
      phone: data['phone']?.toString() ?? phone.trim(),
      expiresIn: _asInt(data['expires_in']),
    );
  }

  @override
  Future<RegisterResult> register(RegisterRequest request) async {
    final envelope = await _api.post(
      '/auth/register',
      body: {
        'first_name': request.firstName.trim(),
        'last_name': request.lastName.trim(),
        'email': request.email.trim(),
        'phone': request.phone.trim(),
        'phone_verification_token': request.phoneVerificationToken,
        'password': request.password,
        'password_confirmation': request.passwordConfirmation,
        'accept_terms': request.acceptTerms,
        'registration_context': 'individual_student',
        'device_name': deviceName,
      },
    );

    final data = _asJsonMap(envelope['data']);
    final email = _asJsonMap(data['user'])['email']?.toString() ??
        request.email.trim();
    final verificationRequired =
        data['email_verification_required'] == true || data['token'] == null;

    if (verificationRequired) {
      return RegisterEmailVerificationRequired(email: email);
    }

    final session = _sessionFromData(data);
    await _persist(session);
    return RegisterSuccess(session);
  }

  @override
  Future<void> clearSession() => _tokens.clear();

  AuthSession _sessionFromData(Map<String, dynamic> data) {
    final userRaw = data['user'];
    final tokenRaw = data['token'];
    if (userRaw is! Map || tokenRaw is! Map) {
      throw StateError('Auth response missing user/token.');
    }
    final user = AuthUser.fromJson(
      userRaw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final tokens = AuthTokens.fromJson(
      tokenRaw.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (user.id.isEmpty || tokens.accessToken.isEmpty) {
      throw StateError('Auth response incomplete.');
    }
    return AuthSession(user: user, tokens: tokens);
  }

  Future<void> _persist(AuthSession session) async {
    await _tokens.saveSession(
      accessToken: session.tokens.accessToken,
      refreshToken: session.tokens.refreshToken,
      userJson: jsonEncode({
        'id': session.user.id,
        'email': session.user.email,
        'first_name': session.user.firstName,
        'last_name': session.user.lastName,
        'phone': session.user.phone,
        'status': session.user.status,
      }),
    );
  }

  static Map<String, dynamic> _asJsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
