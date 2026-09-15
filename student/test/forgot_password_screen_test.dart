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
  Future<void> clearSession() async {}
}

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

    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
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

    await tester.enterText(find.byType(TextField), 'student@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
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

    await tester.enterText(find.byType(TextField), 'student@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();

    expect(
      find.text('Too many reset attempts. Try again later.'),
      findsOneWidget,
    );
  });
}
