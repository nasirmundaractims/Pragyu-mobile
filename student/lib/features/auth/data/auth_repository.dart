import 'dart:convert';

import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/features/auth/data/secure_token_store.dart';
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

  Future<void> clearSession();
}

class AuthRepository implements AuthGateway {
  AuthRepository({
    ApiClient? apiClient,
    TokenStore? tokenStore,
  })  : _api = apiClient ?? ApiClient(),
        _tokens = tokenStore ?? SecureTokenStore();

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

    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
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
    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    final session = _sessionFromData(data);
    await _persist(session);
    return session;
  }

  @override
  Future<void> clearSession() => _tokens.clear();

  AuthSession _sessionFromData(Map<String, dynamic> data) {
    final userRaw = data['user'];
    final tokenRaw = data['token'];
    if (userRaw is! Map || tokenRaw is! Map) {
      throw StateError('Login response missing user/token.');
    }
    final user = AuthUser.fromJson(
      userRaw.map((k, v) => MapEntry(k.toString(), v)),
    );
    final tokens = AuthTokens.fromJson(
      tokenRaw.map((k, v) => MapEntry(k.toString(), v)),
    );
    if (user.id.isEmpty || tokens.accessToken.isEmpty) {
      throw StateError('Login response incomplete.');
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
}
