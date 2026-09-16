import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/attempt_instructions_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests({
    required this.detail,
    this.onStart,
  });

  final AssessmentDetailSnapshot detail;
  final Future<AssessmentAttemptSession> Function(String assessmentId)? onStart;

  int startCalls = 0;

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
    startCalls += 1;
    if (onStart != null) return onStart!(assessmentId);
    throw StateError('start not stubbed');
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

  testWidgets('S-42 requires ack before Start test and opens S-43', (
    tester,
  ) async {
    Object? playerArgs;
    final fake = _FakeTests(
      detail: const AssessmentDetailSnapshot(
        assessment: AssessmentDetail(
          id: 'a1',
          title: 'Polity Weekly Quiz',
          type: TestKind.quiz,
          instructions: 'No phones during the exam.',
          durationMinutes: 30,
          totalMarks: 50,
          questionsCount: 25,
        ),
        studentProfileId: 'sp1',
      ),
      onStart: (id) async {
        return const AssessmentAttemptSession(
          attempt: AssessmentAttemptSummary(
            id: 'att1',
            assessmentId: 'a1',
            status: AttemptLifecycle.inProgress,
          ),
          submission: SubmissionSummary(
            id: 'sub1',
            assessmentId: 'a1',
            status: 'draft',
            assessmentAttemptId: 'att1',
          ),
        );
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttemptInstructionsScreen(
          args: const AttemptInstructionsArgs(
            assessmentId: 'a1',
            title: 'Polity Weekly Quiz',
          ),
          testsRepository: fake,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.attemptPlayer) {
            playerArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Attempt player')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Computer Based Test'), findsOneWidget);
    expect(find.text('No phones during the exam.'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);

    final startFinder = find.text('Start test');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    await tester.tap(
      find.text('I have read and understood all instructions.'),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(startFinder);
    await tester.pumpAndSettle();

    expect(fake.startCalls, 1);
    expect(find.text('Attempt player'), findsOneWidget);
    expect(playerArgs, isA<AttemptPlayerArgs>());
    expect((playerArgs! as AttemptPlayerArgs).attemptId, 'att1');
    expect((playerArgs! as AttemptPlayerArgs).submissionId, 'sub1');
  });

  testWidgets('S-42 continue reuses open session without new start', (
    tester,
  ) async {
    Object? playerArgs;
    final fake = _FakeTests(
      detail: const AssessmentDetailSnapshot(
        assessment: AssessmentDetail(
          id: 'a1',
          title: 'Drill',
          type: TestKind.practice,
        ),
        studentProfileId: 'sp1',
        activeAttempt: AssessmentAttemptSummary(
          id: 'att9',
          assessmentId: 'a1',
          status: AttemptLifecycle.inProgress,
        ),
        activeSubmission: SubmissionSummary(
          id: 'sub9',
          assessmentId: 'a1',
          status: 'draft',
          assessmentAttemptId: 'att9',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttemptInstructionsScreen(
          args: const AttemptInstructionsArgs(
            assessmentId: 'a1',
            attemptId: 'att9',
            submissionId: 'sub9',
          ),
          testsRepository: fake,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.attemptPlayer) {
            playerArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Attempt player')),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    final startFinder = find.text('Start test', skipOffstage: false);
    await tester.ensureVisible(startFinder);
    await tester.pumpAndSettle();
    expect(startFinder, findsOneWidget);
    await tester.tap(
      find.text('I have read and understood all instructions.'),
    );
    await tester.pumpAndSettle();
    await tester.tap(startFinder);
    await tester.pumpAndSettle();

    expect(fake.startCalls, 0);
    expect((playerArgs! as AttemptPlayerArgs).attemptId, 'att9');
    expect((playerArgs! as AttemptPlayerArgs).submissionId, 'sub9');
  });
}
