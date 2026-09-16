import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/data/home_repository.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';
import 'package:student_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/tests_hub_screen.dart';

class _FakeHome implements HomeGateway {
  @override
  Future<HomeSnapshot> loadHome() async {
    return const HomeSnapshot(
      user: AuthUser(id: '1', email: 'a@b.com', firstName: 'Alex'),
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async {
    return TodaySnapshot(day: DateTime(2026, 9, 15));
  }
}

class _FakeTests implements TestsGateway {
  _FakeTests(this.snapshot);

  final TestsSnapshot snapshot;

  @override
  Future<TestsSnapshot> loadTests() async => snapshot;

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(String assessmentId) async {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionSummary> finalizeSubmission(String submissionId) async {
    throw UnimplementedError();
  }

  @override
  Future<AttemptPlayerSnapshot> loadAttemptPlayer(
    AttemptPlayerArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateSubmissionMetadata(
    String submissionId,
    Map<String, dynamic> metadata,
  ) async {}

  @override
  Future<SubmissionStatusPayload> getSubmissionStatus(
    String submissionId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ResultFeedbackSnapshot> loadResultFeedback(
    ResultFeedbackArgs args,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> listSuggestions(String evaluationId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(String feedbackId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> requestRewrite(
    String evaluationId,
    RewriteOptions options,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary?> getLatestRewrite(String evaluationId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> getRewriteRequest(String rewriteRequestId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(String rewriteRequestId) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteRequestSummary> processRewrite(String rewriteRequestId) async {
    throw UnimplementedError();
  }

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-40 lists published tests with type and due', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(
            TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Polity Weekly Quiz',
                  type: TestKind.quiz,
                  durationMinutes: 30,
                  totalMarks: 50,
                  questionsCount: 25,
                  due: const DueState(
                    urgency: DueUrgency.dueToday,
                    label: 'Due today',
                  ),
                ),
                const TestListItem(
                  id: 'a2',
                  title: 'GS Mock Exam',
                  type: TestKind.exam,
                  durationMinutes: 120,
                  totalMarks: 200,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tests'), findsOneWidget);
    expect(find.text('Polity Weekly Quiz'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(find.textContaining('Quiz'), findsWidgets);
    expect(find.text('GS Mock Exam'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
  });

  testWidgets('S-40 empty assigned list', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(const TestsSnapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tests assigned yet.'), findsOneWidget);
  });

  testWidgets('S-40 Tests tab shows hub', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StudentShell(
          initialIndex: 2,
          homeRepository: _FakeHome(),
          testsRepository: _FakeTests(
            const TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Current Affairs Drill',
                  type: TestKind.practice,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tests'), findsWidgets);
    expect(find.text('Current Affairs Drill'), findsOneWidget);
    expect(find.text('S-40 is next'), findsNothing);
  });

  testWidgets('S-40 filter Due soon and row opens S-41', (tester) async {
    Object? pushedArgs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TestsHubScreen(
          testsRepository: _FakeTests(
            TestsSnapshot(
              items: [
                TestListItem(
                  id: 'a1',
                  title: 'Due Quiz',
                  type: TestKind.quiz,
                  due: const DueState(
                    urgency: DueUrgency.dueToday,
                    label: 'Due today',
                  ),
                ),
                const TestListItem(
                  id: 'a2',
                  title: 'Later Exam',
                  type: TestKind.exam,
                ),
              ],
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.assessmentDetail) {
            pushedArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Assessment detail')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Due soon'));
    await tester.pumpAndSettle();

    expect(find.text('Due Quiz'), findsOneWidget);
    expect(find.text('Later Exam'), findsNothing);

    await tester.tap(find.text('Due Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment detail'), findsOneWidget);
    expect(pushedArgs, isA<AssessmentDetailArgs>());
    expect((pushedArgs! as AssessmentDetailArgs).assessmentId, 'a1');
  });
}
