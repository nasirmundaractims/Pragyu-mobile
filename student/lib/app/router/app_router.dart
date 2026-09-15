import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/auth_success_stub_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/welcome/presentation/screens/auth_flow_stub_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';

/// Central route names. S-05 Org picker is not implemented yet.
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const createAccountStub = '/create-account-stub';
  static const authSuccessStub = '/auth-success-stub';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
    case AppRoutes.welcome:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const WelcomeScreen(),
      );
    case AppRoutes.signIn:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SignInScreen(),
      );
    case AppRoutes.forgotPassword:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ForgotPasswordScreen(),
      );
    case AppRoutes.createAccountStub:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AuthFlowStubScreen(
          title: 'Create account',
          nextScreenId: 'Create account',
        ),
      );
    case AppRoutes.authSuccessStub:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AuthSuccessStubScreen(),
      );
    default:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
  }
}
