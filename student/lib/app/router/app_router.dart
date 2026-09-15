import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/organization/presentation/screens/org_picker_screen.dart';
import '../../features/organization/presentation/screens/post_auth_stub_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/welcome/presentation/screens/auth_flow_stub_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';

/// Central route names. S-06 Onboarding is not implemented yet.
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const orgPicker = '/org-picker';
  static const createAccountStub = '/create-account-stub';
  static const postAuthStub = '/post-auth-stub';
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
    case AppRoutes.orgPicker:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const OrgPickerScreen(),
      );
    case AppRoutes.createAccountStub:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AuthFlowStubScreen(
          title: 'Create account',
          nextScreenId: 'Create account',
        ),
      );
    case AppRoutes.postAuthStub:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const PostAuthStubScreen(),
      );
    default:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
  }
}
