import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/session/auth_navigation.dart';
import 'package:student_mobile/features/onboarding/data/memory_onboarding_store.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

import 'support/fake_organization_gateway.dart';

void main() {
  tearDown(() {
    AuthNavigation.organizationGatewayOverride = null;
    AuthNavigation.onboardingStoreOverride = null;
  });

  test('1.5 incomplete tips route to onboarding after workspace ready', () async {
    AuthNavigation.organizationGatewayOverride = FakeOrganizationGateway(
      organizations: const [
        OrganizationSummary(
          id: 'org-1',
          name: 'Demo Institute',
          type: 'organisation',
        ),
      ],
    );
    AuthNavigation.onboardingStoreOverride = MemoryOnboardingStore();

    final route = await AuthNavigation.resolveWorkspaceRoute();
    expect(route, AppRoutes.onboarding);
  });

  test('1.5 completed tips route to home', () async {
    AuthNavigation.organizationGatewayOverride = FakeOrganizationGateway(
      organizations: const [
        OrganizationSummary(
          id: 'org-1',
          name: 'Demo Institute',
          type: 'organisation',
        ),
      ],
    );
    AuthNavigation.onboardingStoreOverride =
        MemoryOnboardingStore(completed: true);

    final route = await AuthNavigation.resolveWorkspaceRoute();
    expect(route, AppRoutes.home);
  });

  test('1.5 no memberships still prefer org association over onboarding',
      () async {
    AuthNavigation.organizationGatewayOverride = FakeOrganizationGateway(
      organizations: const [],
    );
    AuthNavigation.onboardingStoreOverride = MemoryOnboardingStore();

    final route = await AuthNavigation.resolveWorkspaceRoute();
    expect(route, AppRoutes.orgAssociation);
  });
}
