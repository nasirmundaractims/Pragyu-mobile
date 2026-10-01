import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:student_mobile/features/onboarding/data/prefs_onboarding_store.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

/// Shared post-auth navigation helpers.
abstract final class AuthNavigation {
  /// Optional override for tests / DI without changing screen constructors.
  static OrganizationGateway? organizationGatewayOverride;

  /// Optional override for tests / DI (slice 1.5 onboarding gate).
  static OnboardingStore? onboardingStoreOverride;

  /// Clears the entire stack and opens [route].
  static void goAndClear(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  /// Resolves where a signed-in user should land (cold start / guest redirect).
  static Future<String> resolveEntryRoute({
    SessionService? sessionService,
    OnboardingStore? onboardingStore,
    OrganizationGateway? organizationRepository,
  }) async {
    final session = sessionService ?? SessionService();

    if (!await session.hasAccessToken()) {
      return AppRoutes.signIn;
    }

    return resolveWorkspaceRoute(
      sessionService: session,
      onboardingStore: onboardingStore,
      organizationRepository: organizationRepository,
    );
  }

  /// Resolves organisation vs individual workspace after authentication.
  ///
  /// Priority:
  /// 1. Active organisation (non-individual) learner membership → Home/Onboarding
  /// 2. Individual workspace → Home/Onboarding
  /// 3. No learner memberships → organisation association (code or Individual)
  ///
  /// Slice 1.5: when a workspace is ready and tips are not completed, land on
  /// `/onboarding` once. Completing or skipping tips marks the store and opens Home.
  ///
  /// Never opens the all-organisations picker after login. When multiple learner
  /// workspaces exist, the stored org (if still valid) or the first one is used.
  static Future<String> resolveWorkspaceRoute({
    SessionService? sessionService,
    OnboardingStore? onboardingStore,
    OrganizationGateway? organizationRepository,
  }) async {
    final session = sessionService ?? SessionService();
    final orgs = organizationRepository ??
        organizationGatewayOverride ??
        OrganizationRepository();

    // Tests inject [organizationGatewayOverride] without a usable token store.
    if (organizationGatewayOverride == null) {
      if (!await session.hasAccessToken()) {
        return AppRoutes.signIn;
      }
    }

    try {
      final memberships = await orgs.listOrganizations(learnerWorkspaceOnly: true);
      final institutes = memberships.where((o) => o.isOrganisation).toList();
      final individuals = memberships.where((o) => o.isIndividual).toList();
      final storedId = await orgs.readActiveOrganizationId();

      if (institutes.isNotEmpty) {
        final selected = _pickMembership(
          candidates: institutes,
          storedId: storedId,
        );
        await orgs.selectOrganization(selected ?? institutes.first);
        return await homeOrOnboarding(onboardingStore: onboardingStore);
      }

      if (individuals.isNotEmpty) {
        final selected = _pickMembership(
          candidates: individuals,
          storedId: storedId,
        );
        await orgs.selectOrganization(selected ?? individuals.first);
        return await homeOrOnboarding(onboardingStore: onboardingStore);
      }

      return AppRoutes.orgAssociation;
    } catch (_) {
      final full = await session.read();
      if (full != null) {
        return await homeOrOnboarding(onboardingStore: onboardingStore);
      }
      return AppRoutes.orgAssociation;
    }
  }

  /// Home when tips are done; otherwise onboarding (once).
  static Future<String> homeOrOnboarding({
    OnboardingStore? onboardingStore,
  }) async {
    final store =
        onboardingStore ?? onboardingStoreOverride ?? PrefsOnboardingStore();
    if (!await store.hasCompleted()) {
      return AppRoutes.onboarding;
    }
    return AppRoutes.home;
  }

  /// Navigates to the resolved workspace after login/register.
  static Future<void> goToResolvedWorkspace(
    BuildContext context, {
    OrganizationGateway? organizationRepository,
    OnboardingStore? onboardingStore,
  }) async {
    final route = await resolveWorkspaceRoute(
      organizationRepository: organizationRepository,
      onboardingStore: onboardingStore,
    );
    if (!context.mounted) return;
    goAndClear(context, route);
  }

  /// If already authenticated, leave guest screens for the post-auth entry.
  static Future<bool> redirectIfAuthenticated(BuildContext context) async {
    final route = await resolveEntryRoute();
    if (route == AppRoutes.signIn) return false;
    if (!context.mounted) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      goAndClear(context, route);
    });
    return true;
  }

  static OrganizationSummary? _pickMembership({
    required List<OrganizationSummary> candidates,
    required String? storedId,
  }) {
    if (candidates.isEmpty) return null;
    if (storedId != null && storedId.isNotEmpty) {
      for (final org in candidates) {
        if (org.id == storedId) return org;
      }
    }
    return candidates.first;
  }
}
