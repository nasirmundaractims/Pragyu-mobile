import 'package:flutter/material.dart';

import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/onboarding/data/onboarding_store.dart';
import 'package:student_mobile/features/onboarding/data/prefs_onboarding_store.dart';

/// Shared post-auth navigation helpers.
abstract final class AuthNavigation {
  /// Clears the entire stack (welcome/sign-in) and opens [route].
  static void goAndClear(BuildContext context, String route) {
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  /// Resolves where a signed-in user should land.
  static Future<String> resolveEntryRoute({
    SessionService? sessionService,
    OnboardingStore? onboardingStore,
  }) async {
    final session = sessionService ?? SessionService();
    final onboarding = onboardingStore ?? PrefsOnboardingStore();

    if (!await session.hasAccessToken()) {
      return AppRoutes.welcome;
    }

    final full = await session.read();
    if (full == null) {
      return AppRoutes.orgPicker;
    }

    if (!await onboarding.hasCompleted()) {
      return AppRoutes.onboarding;
    }

    return AppRoutes.home;
  }

  /// If already authenticated, leave guest screens for the post-auth entry.
  static Future<bool> redirectIfAuthenticated(BuildContext context) async {
    final route = await resolveEntryRoute();
    if (route == AppRoutes.welcome) return false;
    if (!context.mounted) return true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      goAndClear(context, route);
    });
    return true;
  }
}
