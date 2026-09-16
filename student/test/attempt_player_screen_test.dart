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
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/attempt_player_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests({
    required this.snapshot,
    this.onUpdate,
    this.onFinalize,
  });

  AttemptPlayerSnapshot snapshot;
  final Future<void> Function(String id, Map<String, dynamic> metadata)?
      onUpdate;
  final Future<SubmissionSummary> Function(String id)? onFinalize;

  final List<Map<String, dynamic>> updates = [];
  int finalizeCalls = 0;

  @override
  Future<TestsSnapshot> loadTests() async => const TestsSnapshot();

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
    finalizeCalls += 1;
    if (onFinalize != null) return onFinalize!(submissionId);
    return SubmissionSummary(
      id: submissionId,
      assessmentId: snapshot.assessment.id,
      status: 'pending',
    );
  }

  @override
  Future<AttemptPlayerSnapshot> loadAttemptPlayer(
    AttemptPlayerArgs args,
  ) async {
    return snapshot;
  }

  @override
  Future<void> updateSubmissionMetadata(
    String submissionId,
    Map<String, dynamic> metadata,
  ) async {
    updates.add(Map<String, dynamic>.from(metadata));
    if (onUpdate != null) await onUpdate!(submissionId, metadata);
  }

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

  AttemptPlayerSnapshot baseSnapshot() {
    final now = DateTime.now();
    return AttemptPlayerSnapshot(
      assessment: const AssessmentDetail(
        id: 'a1',
        title: 'Polity Weekly Quiz',
        type: TestKind.quiz,
        durationMinutes: 30,
      ),
      questions: const [
        AssessmentQuestionPreview(
          id: 'link1',
          questionId: 'q1',
          sortOrder: 1,
          content: 'What is Article 14?',
          type: 'mcq',
          maxMarks: 2,
          choices: [
            AnswerChoice(id: 'a', label: 'Equality before law'),
            AnswerChoice(id: 'b', label: 'Freedom of speech'),
          ],
        ),
        AssessmentQuestionPreview(
          id: 'link2',
          questionId: 'q2',
          sortOrder: 2,
          content: 'Is the preamble part of the Constitution?',
          type: 'true_false',
          maxMarks: 1,
        ),
        AssessmentQuestionPreview(
          id: 'link3',
          questionId: 'q3',
          sortOrder: 3,
          content: 'Define secularism briefly.',
          type: 'short_answer',
          maxMarks: 5,
        ),
      ],
      answers: const {},
      player: CbtPlayerState(
        currentQuestionId: 'q1',
        visited: const ['q1'],
        instructionsAcked: true,
        startedAt: now,
        deadlineAt: now.add(const Duration(hours: 1)),
      ),
      submissionId: 'sub1',
      attemptId: 'att1',
    );
  }

  testWidgets('S-43 answers MCQ and advances', (tester) async {
    final fake = _FakeTests(snapshot: baseSnapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttemptPlayerScreen(
          args: const AttemptPlayerArgs(
            assessmentId: 'a1',
            attemptId: 'att1',
            submissionId: 'sub1',
            title: 'Polity Weekly Quiz',
          ),
          testsRepository: fake,
          autosaveDebounce: const Duration(milliseconds: 10),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('What is Article 14?'), findsOneWidget);
    expect(find.text('Question 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Equality before law'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Is the preamble part of the Constitution?'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(fake.updates, isNotEmpty);
    final answers = fake.updates.last['answers'] as Map;
    expect(answers['q1'], isA<Map>());
    expect((answers['q1'] as Map)['choiceId'], 'a');
  });

  testWidgets('S-43 submit confirm opens S-45 status', (tester) async {
    Object? statusArgs;
    final fake = _FakeTests(snapshot: baseSnapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AttemptPlayerScreen(
          args: const AttemptPlayerArgs(
            assessmentId: 'a1',
            attemptId: 'att1',
            submissionId: 'sub1',
          ),
          testsRepository: fake,
          autosaveDebounce: const Duration(milliseconds: 10),
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

    final submitFinder = find.text('Submit test', skipOffstage: false);
    await tester.ensureVisible(submitFinder);
    await tester.pumpAndSettle();
    await tester.tap(submitFinder);
    await tester.pumpAndSettle();

    expect(find.text('Submit test?'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    await tester.tap(find.text('Submit now'));
    await tester.pumpAndSettle();

    expect(fake.finalizeCalls, 1);
    expect(find.text('Submission status'), findsOneWidget);
    expect(statusArgs, isA<SubmissionStatusArgs>());
    expect((statusArgs! as SubmissionStatusArgs).submissionId, 'sub1');
    expect(
      fake.updates.any((m) => m['submit_reason'] == 'manual'),
      isTrue,
    );
  });
}
