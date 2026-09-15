import 'package:flutter/material.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/today_detail_screen.dart';
import '../../features/learn/domain/learn_models.dart';
import '../../features/learn/presentation/screens/course_detail_screen.dart';
import '../../features/learn/presentation/screens/lesson_player_screen.dart';
import '../../features/lectures/domain/lecture_models.dart';
import '../../features/lectures/presentation/screens/lectures_list_screen.dart';
import '../../features/lectures/presentation/screens/live_lobby_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/organization/presentation/screens/org_picker_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/welcome/presentation/screens/auth_flow_stub_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';

/// Central route names. Remaining tab roots after Learn are placeholders (S-40+).
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const forgotPassword = '/forgot-password';
  static const orgPicker = '/org-picker';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const todayDetail = '/today';
  static const courseDetail = '/course-detail';
  static const lessonPlayer = '/lesson';
  static const lecturesList = '/lectures';
  static const liveLobby = '/live-lobby';
  static const createAccountStub = '/create-account-stub';
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
    case AppRoutes.onboarding:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const OnboardingScreen(),
      );
    case AppRoutes.home:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const StudentShell(),
      );
    case AppRoutes.todayDetail:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const TodayDetailScreen(),
      );
    case AppRoutes.courseDetail:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => CourseDetailScreen(
          args: CourseDetailArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.lessonPlayer:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LessonPlayerScreen(
          args: LessonDetailArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.lecturesList:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LecturesListScreen(
          args: LecturesListArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.liveLobby:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LiveLobbyScreen(
          args: LiveLobbyArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.createAccountStub:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AuthFlowStubScreen(
          title: 'Create account',
          nextScreenId: 'Create account',
        ),
      );
    default:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const SplashScreen(),
      );
  }
}
