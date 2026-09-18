import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/data/auth_repository.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';
import 'package:student_mobile/features/organization/presentation/screens/org_picker_screen.dart';

class _FakeAuth implements AuthGateway {
  _FakeAuth({
    this.registerResult,
  });

  RegisterResult? registerResult;
  RegisterRequest? lastRegister;
  String? lastOtpPhone;
  String? lastOtpCode;
  int requestOtpCalls = 0;
  int confirmOtpCalls = 0;

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
  Future<void> requestRegistrationPhoneOtp({required String phone}) async {
    requestOtpCalls += 1;
    lastOtpPhone = phone;
  }

  @override
  Future<PhoneOtpConfirmResult> confirmRegistrationPhoneOtp({
    required String phone,
    required String code,
  }) async {
    confirmOtpCalls += 1;
    lastOtpCode = code;
    return PhoneOtpConfirmResult(
      phoneVerificationToken: 'phone-token',
      phone: phone,
    );
  }

  @override
  Future<RegisterResult> register(RegisterRequest request) async {
    lastRegister = request;
    return registerResult ??
        RegisterSuccess(
          AuthSession(
            user: AuthUser(
              id: 'u1',
              email: request.email,
              firstName: request.firstName,
              lastName: request.lastName,
              phone: request.phone,
            ),
            tokens: const AuthTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            ),
          ),
        );
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
    ];
  }

  @override
  Future<void> selectOrganization(OrganizationSummary organization) async {}

  @override
  Future<String?> readActiveOrganizationId() async => null;
}

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

  testWidgets('S-04 register validates required fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: RegisterScreen(authRepository: _FakeAuth()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Create your'), findsOneWidget);
    expect(find.text('Create account'), findsWidgets);

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name'), findsOneWidget);
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Verify your mobile number'), findsOneWidget);
    expect(find.text('Accept the terms to continue'), findsOneWidget);
  });

  testWidgets('S-04 register OTP then creates account and opens org picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeAuth();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _testRoutes,
        home: RegisterScreen(authRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Ada');
    await tester.enterText(find.byType(TextField).at(1), 'Lovelace');
    await tester.enterText(find.byType(TextField).at(2), 'ada@example.com');
    await tester.enterText(find.byType(TextField).at(3), '+919876543210');

    await tester.ensureVisible(find.text('Send OTP'));
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();
    expect(fake.requestOtpCalls, 1);

    await tester.enterText(find.byType(TextField).at(4), '123456');
    await tester.ensureVisible(find.text('Verify mobile'));
    await tester.tap(find.text('Verify mobile'));
    await tester.pumpAndSettle();
    expect(fake.confirmOtpCalls, 1);
    expect(find.text('Mobile number verified'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(4), 'Password1!');
    await tester.enterText(find.byType(TextField).at(5), 'Password1!');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account').last);
    await tester.tap(find.text('Create account').last);
    await tester.pumpAndSettle();

    expect(fake.lastRegister?.email, 'ada@example.com');
    expect(fake.lastRegister?.phoneVerificationToken, 'phone-token');
    expect(find.text('Acme Institute'), findsOneWidget);
  });
}
