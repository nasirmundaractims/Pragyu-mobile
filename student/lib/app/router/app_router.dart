import 'package:flutter/material.dart';

import '../../features/ai_mentor/presentation/screens/ai_mentor_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/catalog/presentation/screens/catalog_browse_screen.dart';
import '../../features/catalog/presentation/screens/catalog_detail_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/today_detail_screen.dart';
import '../../features/learn/domain/learn_models.dart';
import '../../features/learn/presentation/screens/course_detail_screen.dart';
import '../../features/learn/presentation/screens/lesson_player_screen.dart';
import '../../features/lectures/domain/lecture_models.dart';
import '../../features/lectures/presentation/screens/lectures_list_screen.dart';
import '../../features/lectures/presentation/screens/live_lobby_screen.dart';
import '../../features/lectures/presentation/screens/live_room_screen.dart';
import '../../features/lectures/presentation/screens/recorded_lecture_screen.dart';
import '../../features/materials/domain/material_models.dart';
import '../../features/materials/presentation/screens/material_viewer_screen.dart';
import '../../features/materials/presentation/screens/study_materials_list_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/organization/presentation/screens/org_picker_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/tests/domain/assessment_detail_models.dart';
import '../../features/tests/domain/attempt_flow_models.dart';
import '../../features/tests/domain/deep_feedback_models.dart';
import '../../features/tests/domain/submission_status_models.dart';
import '../../features/tests/presentation/screens/assessment_detail_screen.dart';
import '../../features/tests/presentation/screens/attempt_instructions_screen.dart';
import '../../features/tests/presentation/screens/attempt_player_screen.dart';
import '../../features/tests/presentation/screens/deep_feedback_screen.dart';
import '../../features/tests/presentation/screens/past_results_screen.dart';
import '../../features/tests/presentation/screens/result_feedback_screen.dart';
import '../../features/tests/presentation/screens/submission_status_screen.dart';
import '../../features/welcome/presentation/screens/auth_flow_stub_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';

/// Central route names.
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
  static const liveRoom = '/live-room';
  static const recordedLecture = '/recorded-lecture';
  static const studyMaterials = '/study-materials';
  static const materialViewer = '/material-viewer';
  static const calendar = '/calendar';
  static const catalog = '/catalog';
  static const catalogDetail = '/catalog-detail';
  static const assessmentDetail = '/assessment-detail';
  static const attemptInstructions = '/attempt-instructions';
  static const attemptPlayer = '/attempt-player';
  static const submissionStatus = '/submission-status';
  static const resultFeedback = '/result-feedback';
  static const deepFeedback = '/deep-feedback';
  static const pastResults = '/past-results';
  static const aiMentor = '/ai-mentor';
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
    case AppRoutes.liveRoom:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => LiveRoomScreen(
          args: LiveRoomArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.recordedLecture:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => RecordedLectureScreen(
          args: RecordedLectureArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.studyMaterials:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => StudyMaterialsListScreen(
          args: StudyMaterialsListArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.materialViewer:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => MaterialViewerScreen(
          args: MaterialViewerArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.calendar:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const CalendarScreen(),
      );
    case AppRoutes.catalog:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const CatalogBrowseScreen(),
      );
    case AppRoutes.catalogDetail:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => CatalogDetailScreen(
          slug: settings.arguments is String
              ? settings.arguments as String
              : settings.arguments?.toString() ?? '',
        ),
      );
    case AppRoutes.assessmentDetail:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AssessmentDetailScreen(
          args: AssessmentDetailArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.attemptInstructions:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AttemptInstructionsScreen(
          args: AttemptInstructionsArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.attemptPlayer:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => AttemptPlayerScreen(
          args: AttemptPlayerArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.submissionStatus:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => SubmissionStatusScreen(
          args: SubmissionStatusArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.resultFeedback:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ResultFeedbackScreen(
          args: ResultFeedbackArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.deepFeedback:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => DeepFeedbackScreen(
          args: DeepFeedbackArgs.fromObject(settings.arguments),
        ),
      );
    case AppRoutes.pastResults:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const PastResultsScreen(),
      );
    case AppRoutes.aiMentor:
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AiMentorScreen(),
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
