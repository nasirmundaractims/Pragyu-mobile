import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/forgot_password_screen.dart';

class _FakeAuth implements AuthGateway {
  _FakeAuth({this.forgotError});

  Object? forgotError;
  int forgotCalls = 0;
  String? lastForgotEmail;

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
  Future<void> forgotPassword({required String email}) async {
    forgotCalls += 1;
    lastForgotEmail = email;
    final error = forgotError;
    if (error != null) throw error;
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    throw UnimplementedError();
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

Finder _sendResetButton() => find.text('Send reset link');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-04 validates empty email', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ForgotPasswordScreen(authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(_sendResetButton());
    await tester.tap(_sendResetButton());
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(auth.forgotCalls, 0);
  });

  testWidgets('S-04 sends reset link and shows confirmation', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ForgotPasswordScreen(authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'student@example.com');
    await tester.ensureVisible(_sendResetButton());
    await tester.tap(_sendResetButton());
    await tester.pumpAndSettle();

    expect(auth.forgotCalls, 1);
    expect(auth.lastForgotEmail, 'student@example.com');
    expect(find.text('Check your inbox'), findsOneWidget);
  });

  testWidgets('S-04 shows API error message', (tester) async {
    final auth = _FakeAuth(
      forgotError: ApiException(
        message: 'Too many reset attempts. Try again later.',
        statusCode: 429,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ForgotPasswordScreen(authRepository: auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'student@example.com');
    await tester.ensureVisible(_sendResetButton());
    await tester.tap(_sendResetButton());
    await tester.pumpAndSettle();

    expect(
      find.text('Too many reset attempts. Try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('S-04 forgot password has no overflow across phone sizes',
      (tester) async {
    const sizes = <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(430, 932),
    ];

    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: ForgotPasswordScreen(authRepository: _FakeAuth()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'scrolled $size');
    }

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
