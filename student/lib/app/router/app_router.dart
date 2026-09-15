import 'package:flutter/material.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/startup/presentation/screens/startup_placeholder_screen.dart';

/// Central route names. S-02 Welcome is intentionally not implemented yet.
abstract final class AppRoutes {
  static const splash = '/';
  static const startupPlaceholder = '/startup-placeholder';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
    case AppRoutes.startupPlaceholder:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const StartupPlaceholderScreen(),
      );
    default:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
  }
}
