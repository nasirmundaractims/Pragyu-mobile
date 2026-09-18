import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/verify_email_screen.dart';

class _FakeAuth implements AuthGateway {
  _FakeAuth({
    this.verifyError,
    this.resendError,
    this.resendSent = true,
  });

  Object? verifyError;
  Object? resendError;
  bool resendSent;
  int verifyCalls = 0;
  int resendCalls = 0;
  String? lastVerifyId;
  String? lastVerifyToken;
  String? lastResendEmail;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> verifyMfaLogin({
    required String challengeToken,
    required String code,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {}

  @override
  Future<AuthUser> verifyEmail({
    required String id,
    required String token,
  }) async {
    verifyCalls += 1;
    lastVerifyId = id;
    lastVerifyToken = token;
    final error = verifyError;
    if (error != null) throw error;
    return AuthUser(id: id, email: 'student@example.com');
  }

  @override
  Future<bool> resendVerification({
    String? email,
    String? identityId,
  }) async {
    resendCalls += 1;
    lastResendEmail = email;
    final error = resendError;
    if (error != null) throw error;
    return resendSent;
  }

  @override
  Future<void> requestRegistrationPhoneOtp({required String phone}) async {}

  @override
  Future<PhoneOtpConfirmResult> confirmRegistrationPhoneOtp({
    required String phone,
    required String code,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RegisterResult> register(RegisterRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<void> clearSession() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('verify email auto-confirms id+token', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: VerifyEmailScreen(
          args: const VerifyEmailArgs(id: 'user-1', token: 'tok-1'),
          authRepository: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(auth.verifyCalls, 1);
    expect(auth.lastVerifyId, 'user-1');
    expect(auth.lastVerifyToken, 'tok-1');
    expect(find.text('Continue to sign in'), findsOneWidget);
  });

  testWidgets('verify email resends for email-only flow', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: VerifyEmailScreen(
          args: const VerifyEmailArgs(email: 'student@example.com'),
          authRepository: auth,
        ),
      ),
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Resend verification email'),
    );
    await tester.pumpAndSettle();

    expect(auth.resendCalls, 1);
    expect(auth.lastResendEmail, 'student@example.com');
    expect(auth.verifyCalls, 0);
  });

  testWidgets('verify email shows API error on bad token', (tester) async {
    final auth = _FakeAuth(
      verifyError: ApiException(
        message: 'Verification link is invalid or expired.',
        statusCode: 400,
        code: 'AUTH_008',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.signIn) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Sign in')),
            );
          }
          return null;
        },
        home: VerifyEmailScreen(
          args: const VerifyEmailArgs(id: 'user-1', token: 'bad'),
          authRepository: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Verification link is invalid or expired.'),
      findsWidgets,
    );
    expect(find.text('Resend verification email'), findsOneWidget);
  });
}
