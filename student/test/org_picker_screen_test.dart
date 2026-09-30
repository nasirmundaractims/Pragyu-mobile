import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/onboarding/data/memory_onboarding_store.dart';
import 'package:student_mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';
import 'package:student_mobile/features/organization/presentation/screens/org_picker_screen.dart';

import 'support/fake_organization_gateway.dart';

Route<dynamic> _routes(RouteSettings settings) {
  if (settings.name == AppRoutes.onboarding) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => OnboardingScreen(
        onboardingStore: MemoryOnboardingStore(),
        forceShow: true,
      ),
    );
  }
  if (settings.name == AppRoutes.orgAssociation) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(
        body: Center(child: Text('Are you associated with an organisation?')),
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

  testWidgets('S-05 shows empty state when no orgs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _routes,
        home: OrgPickerScreen(
          organizationRepository: FakeOrganizationGateway(),
          autoSelectSingle: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up your learning space'), findsOneWidget);
  });

  testWidgets('S-05 lists institutes for selection', (tester) async {
    final fake = FakeOrganizationGateway(
      organizations: const [
        OrganizationSummary(
          id: 'org-1',
          name: 'Acme Institute',
          type: 'institute',
          status: 'active',
        ),
        OrganizationSummary(
          id: 'org-2',
          name: 'Beta College',
          type: 'institute',
          status: 'trial',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _routes,
        home: OrgPickerScreen(
          organizationRepository: fake,
          autoSelectSingle: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acme Institute'), findsOneWidget);
    expect(find.text('Beta College'), findsOneWidget);

    await tester.tap(find.text('Acme Institute'));
    await tester.pumpAndSettle();

    expect(fake.selected?.id, 'org-1');
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('S-05 auto-selects single institute', (tester) async {
    final fake = FakeOrganizationGateway(
      organizations: const [
        OrganizationSummary(
          id: 'only-org',
          name: 'Solo Institute',
          type: 'institute',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        onGenerateRoute: _routes,
        home: OrgPickerScreen(organizationRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.selected?.id, 'only-org');
    expect(find.text('Learn'), findsOneWidget);
  });

  testWidgets('S-05 shows load error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OrgPickerScreen(
          organizationRepository: FakeOrganizationGateway(
            listError: ApiException(
              message: 'Unauthorized',
              statusCode: 401,
            ),
          ),
          autoSelectSingle: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unauthorized'), findsOneWidget);
  });
}
