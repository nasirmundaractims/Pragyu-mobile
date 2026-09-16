import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/assessment_detail_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests({
    required this.detail,
    this.onFinalize,
  });

  AssessmentDetailSnapshot detail;
  final Future<SubmissionSummary> Function(String submissionId)? onFinalize;

  int finalizeCalls = 0;

  @override
  Future<TestsSnapshot> loadTests() async => const TestsSnapshot();

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    return detail;
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(String assessmentId) async {
    throw UnimplementedError();
  }

  @override
  Future<SubmissionSummary> finalizeSubmission(String submissionId) async {
    finalizeCalls += 1;
    if (onFinalize != null) {
      final result = await onFinalize!(submissionId);
      detail = AssessmentDetailSnapshot(
        assessment: detail.assessment,
        studentProfileId: detail.studentProfileId,
        finalResult: detail.finalResult,
      );
      return result;
    }
    throw StateError('finalize not stubbed');
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

  @override
  Future<AnswerImageAttachment> uploadAnswerImage({
    required String submissionId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int pageNumber,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PastResultsSnapshot> loadPastResults() async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  testWidgets('S-41 Start attempt opens S-42 instructions', (tester) async {
    Object? pushedArgs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AssessmentDetailScreen(
          args: const AssessmentDetailArgs(
            assessmentId: 'a1',
            title: 'Polity Weekly Quiz',
          ),
          testsRepository: _FakeTests(
            detail: const AssessmentDetailSnapshot(
              assessment: AssessmentDetail(
                id: 'a1',
                title: 'Polity Weekly Quiz',
                type: TestKind.quiz,
                instructions: 'Read carefully before starting.',
                durationMinutes: 30,
                totalMarks: 50,
                questions: [
                  AssessmentQuestionPreview(
                    id: 'q1',
                    sortOrder: 1,
                    content: 'What is Article 14?',
                    maxMarks: 2,
                  ),
                ],
              ),
              studentProfileId: 'sp1',
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.attemptInstructions) {
            pushedArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  const Scaffold(body: Text('Attempt instructions')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polity Weekly Quiz'), findsOneWidget);
    expect(find.text('Read carefully before starting.'), findsOneWidget);
    expect(find.text('What is Article 14?'), findsOneWidget);
    expect(find.text('Start attempt'), findsOneWidget);

    await tester.tap(find.text('Start attempt'));
    await tester.pumpAndSettle();

    expect(find.text('Attempt instructions'), findsOneWidget);
    expect(pushedArgs, isA<AttemptInstructionsArgs>());
    expect((pushedArgs! as AttemptInstructionsArgs).assessmentId, 'a1');
  });

  testWidgets('S-41 shows final result and blocks start without profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AssessmentDetailScreen(
          args: const AssessmentDetailArgs(assessmentId: 'a1'),
          testsRepository: _FakeTests(
            detail: AssessmentDetailSnapshot(
              assessment: AssessmentDetail(
                id: 'a1',
                title: 'GS Mock',
                type: TestKind.exam,
                due: const DueState(
                  urgency: DueUrgency.dueToday,
                  label: 'Due today',
                ),
              ),
              finalResult: const FinalResultSummary(
                id: 'r1',
                marks: 78,
                rank: 12,
                percentile: 91,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your result'), findsOneWidget);
    expect(find.text('78 marks'), findsOneWidget);
    expect(find.textContaining('Rank 12'), findsOneWidget);
    expect(
      find.text(
        'Student profile is required before you can start this test.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start attempt'), findsNothing);
  });

  testWidgets('S-41 continue opens S-42 with session ids', (tester) async {
    Object? pushedArgs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AssessmentDetailScreen(
          args: const AssessmentDetailArgs(assessmentId: 'a1'),
          testsRepository: _FakeTests(
            detail: const AssessmentDetailSnapshot(
              assessment: AssessmentDetail(
                id: 'a1',
                title: 'Drill',
                type: TestKind.practice,
              ),
              studentProfileId: 'sp1',
              activeAttempt: AssessmentAttemptSummary(
                id: 'att1',
                assessmentId: 'a1',
                status: AttemptLifecycle.inProgress,
              ),
              activeSubmission: SubmissionSummary(
                id: 'sub1',
                assessmentId: 'a1',
                status: 'draft',
                assessmentAttemptId: 'att1',
              ),
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.attemptInstructions) {
            pushedArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  const Scaffold(body: Text('Attempt instructions')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    final continueFinder =
        find.text('Continue attempt', skipOffstage: false);
    await tester.ensureVisible(continueFinder);
    await tester.pumpAndSettle();
    await tester.tap(continueFinder);
    await tester.pumpAndSettle();

    expect(find.text('Attempt instructions'), findsOneWidget);
    expect(
      (pushedArgs! as AttemptInstructionsArgs).attemptId,
      'att1',
    );
    expect(
      (pushedArgs! as AttemptInstructionsArgs).submissionId,
      'sub1',
    );
  });

  testWidgets('S-41 submit opens S-45 status', (tester) async {
    Object? statusArgs;
    final fake = _FakeTests(
      detail: const AssessmentDetailSnapshot(
        assessment: AssessmentDetail(
          id: 'a1',
          title: 'Drill',
          type: TestKind.practice,
        ),
        studentProfileId: 'sp1',
        activeAttempt: AssessmentAttemptSummary(
          id: 'att1',
          assessmentId: 'a1',
          status: AttemptLifecycle.inProgress,
        ),
        activeSubmission: SubmissionSummary(
          id: 'sub1',
          assessmentId: 'a1',
          status: 'draft',
          assessmentAttemptId: 'att1',
        ),
      ),
      onFinalize: (id) async {
        return const SubmissionSummary(
          id: 'sub1',
          assessmentId: 'a1',
          status: 'ready_for_evaluation',
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AssessmentDetailScreen(
          args: const AssessmentDetailArgs(assessmentId: 'a1'),
          testsRepository: fake,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.submissionStatus) {
            statusArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Submission status')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    final submitFinder = find.text('Submit attempt', skipOffstage: false);
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(fake.finalizeCalls, 1);
    expect(find.text('Submission status'), findsOneWidget);
    expect(statusArgs, isA<SubmissionStatusArgs>());
    expect(
      (statusArgs! as SubmissionStatusArgs).initialStatus,
      'ready_for_evaluation',
    );
  });
}
