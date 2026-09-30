import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

/// Shared post-auth navigation helpers.
abstract final class AuthNavigation {
  /// Optional override for tests / DI without changing screen constructors.
  static OrganizationGateway? organizationGatewayOverride;

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
  /// 1. Active organisation (non-individual) membership → organisation Home
  /// 2. Individual workspace → Individual Home
  /// 3. No memberships → organisation association (code or Individual)
  ///
  /// Multiple organisations without a stored match → org picker (safe default).
  /// Tips onboarding is never forced — students go straight to Home.
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
      final memberships = await orgs.listOrganizations();
      final institutes = memberships.where((o) => o.isOrganisation).toList();
      final individuals = memberships.where((o) => o.isIndividual).toList();
      final storedId = await orgs.readActiveOrganizationId();

      if (institutes.isNotEmpty) {
        final selected = _pickMembership(
          candidates: institutes,
          storedId: storedId,
        );
        if (selected != null) {
          await orgs.selectOrganization(selected);
          return AppRoutes.home;
        }
        return AppRoutes.orgPicker;
      }

      if (individuals.isNotEmpty) {
        final selected = _pickMembership(
          candidates: individuals,
          storedId: storedId,
        );
        await orgs.selectOrganization(selected ?? individuals.first);
        return AppRoutes.home;
      }

      return AppRoutes.orgAssociation;
    } catch (_) {
      final full = await session.read();
      if (full != null) {
        return AppRoutes.home;
      }
      return AppRoutes.orgAssociation;
    }
  }

  /// Navigates to the resolved workspace after login/register.
  static Future<void> goToResolvedWorkspace(
    BuildContext context, {
    OrganizationGateway? organizationRepository,
  }) async {
    final route = await resolveWorkspaceRoute(
      organizationRepository: organizationRepository,
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
    if (candidates.length == 1) return candidates.first;
    return null;
  }
}
