import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';
import 'package:student_mobile/features/organization/presentation/screens/org_picker_screen.dart';

class _FakeAuth implements AuthGateway {
  _FakeAuth({this.loginError});

  Object? loginError;
  int loginCalls = 0;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    loginCalls += 1;
    final error = loginError;
    if (error != null) throw error;
    return LoginSuccess(
      AuthSession(
        user: const AuthUser(id: '1', email: 'a@b.com'),
        tokens: const AuthTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
        ),
      ),
    );
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

class _FakeOrgs implements OrganizationGateway {
  @override
  Future<List<OrganizationSummary>> listOrganizations() async {
    return const [
      OrganizationSummary(
        id: 'org-1',
        name: 'Acme Institute',
        type: 'institute',
      ),
      OrganizationSummary(
        id: 'org-2',
        name: 'Beta College',
        type: 'institute',
      ),
    ];
  }

  @override
  Future<void> selectOrganization(OrganizationSummary organization) async {}

  @override
  Future<String?> readActiveOrganizationId() async => null;
}

Finder _emailField() => find.byType(TextField).at(0);
Finder _passwordField() => find.byType(TextField).at(1);

Route<dynamic> _testRoutes(RouteSettings settings) {
  if (settings.name == AppRoutes.orgPicker) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => OrgPickerScreen(
        organizationRepository: _FakeOrgs(),
        autoSelectSingle: false,
      ),
    );
  }
  return onGenerateRoute(settings);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-03 validates empty fields', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SignInScreen(authRepository: auth),
      ),
    );

    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(auth.loginCalls, 0);
  });

  testWidgets('S-03 signs in and opens org picker', (tester) async {
    final auth = _FakeAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _testRoutes,
        home: SignInScreen(authRepository: auth),
      ),
    );

    await tester.enterText(_emailField(), 'student@example.com');
    await tester.enterText(_passwordField(), 'Password1!');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
    expect(find.text('Choose institute'), findsOneWidget);
    expect(find.text('Acme Institute'), findsOneWidget);
  });

  testWidgets('S-03 shows API error message', (tester) async {
    final auth = _FakeAuth(
      loginError: ApiException(
        message: 'The provided credentials are invalid.',
        statusCode: 400,
        code: 'AUTH_003',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SignInScreen(authRepository: auth),
      ),
    );

    await tester.enterText(_emailField(), 'student@example.com');
    await tester.enterText(_passwordField(), 'bad-password');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('The provided credentials are invalid.'),
      findsOneWidget,
    );
  });

  testWidgets('S-03 forgot password opens S-04', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: onGenerateRoute,
        home: SignInScreen(authRepository: _FakeAuth()),
      ),
    );
    await tester.pumpAndSettle();

    final forgot = find.text('Forgot password?');
    await tester.scrollUntilVisible(
      forgot,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget);
  });
}
