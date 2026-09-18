import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/reset_password_screen.dart';

class _FakeAuth implements AuthGateway {
  _FakeAuth({this.resetError});

  Object? resetError;
  int resetCalls = 0;
  String? lastEmail;
  String? lastToken;
  String? lastPassword;

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
  }) async {
    resetCalls += 1;
    lastEmail = email;
    lastToken = token;
    lastPassword = password;
    final error = resetError;
    if (error != null) throw error;
  }

  @override
  Future<AuthUser> verifyEmail({
    required String id,
    required String token,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<bool> resendVerification({
    String? email,
    String? identityId,
  }) async {
    throw UnimplementedError();
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

Finder _fieldAt(int index) => find.byType(TextField).at(index);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('reset password validates empty fields', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ResetPasswordScreen(authRepository: auth),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter the reset token from your email'), findsOneWidget);
    expect(auth.resetCalls, 0);
  });

  testWidgets('reset password submits and goes to sign in', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.signIn) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Sign in page')),
            );
          }
          return null;
        },
        home: ResetPasswordScreen(
          args: const ResetPasswordArgs(
            email: 'student@example.com',
            token: 'reset-tok',
          ),
          authRepository: auth,
        ),
      ),
    );

    await tester.enterText(_fieldAt(2), 'NewPass1!');
    await tester.enterText(_fieldAt(3), 'NewPass1!');
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(auth.resetCalls, 1);
    expect(auth.lastEmail, 'student@example.com');
    expect(auth.lastToken, 'reset-tok');
    expect(auth.lastPassword, 'NewPass1!');
    expect(find.text('Sign in page'), findsOneWidget);
  });

  testWidgets('reset password shows API error', (tester) async {
    final auth = _FakeAuth(
      resetError: ApiException(
        message: 'This password reset token is invalid.',
        statusCode: 422,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ResetPasswordScreen(
          args: const ResetPasswordArgs(
            email: 'student@example.com',
            token: 'bad',
          ),
          authRepository: auth,
        ),
      ),
    );

    await tester.enterText(_fieldAt(2), 'NewPass1!');
    await tester.enterText(_fieldAt(3), 'NewPass1!');
    await tester.tap(find.widgetWithText(FilledButton, 'Update password'));
    await tester.pumpAndSettle();

    expect(
      find.text('This password reset token is invalid.'),
      findsOneWidget,
    );
  });
}
