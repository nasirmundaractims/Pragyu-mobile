import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:student_mobile/features/tests/presentation/screens/result_feedback_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests(this.snapshot);

  final ResultFeedbackSnapshot snapshot;

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
    return snapshot;
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

  testWidgets('S-46 shows score breakdown and AI feedback', (tester) async {
    final fake = _FakeTests(
      ResultFeedbackSnapshot(
        submission: const SubmissionSummary(
          id: 'sub1',
          assessmentId: 'a1',
          attemptNumber: 2,
          status: 'evaluated',
          totalScore: 14,
          maxScore: 20,
          percentage: 70,
        ),
        evaluation: const EvaluationSummary(
          id: 'ev1',
          submissionId: 'sub1',
          assessmentId: 'a1',
          totalScore: 14,
          maxScore: 20,
          percentage: 70,
          grade: 'B',
        ),
        scores: const [
          EvaluationScoreItem(
            id: 's1',
            scoreAwarded: 7,
            effectiveScore: 7,
            maxScore: 10,
            feedback: 'Clear structure and relevant examples.',
            rubricBreakdown: {'accuracy': 4, 'clarity': 3},
          ),
          EvaluationScoreItem(
            id: 's2',
            scoreAwarded: 7,
            maxScore: 10,
            feedback: 'Missed a key definition.',
          ),
        ],
        feedback: const EvaluationFeedbackReport(
          id: 'fb1',
          evaluationId: 'ev1',
          summary: 'Solid attempt with room to deepen concepts.',
          strengths: ['Structured answers'],
          weaknesses: ['Thin on definitions'],
          missingConcepts: ['federalism'],
          writingTips: ['Define terms before arguing'],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ResultFeedbackScreen(
          args: const ResultFeedbackArgs(
            submissionId: 'sub1',
            assessmentId: 'a1',
            title: 'Polity Weekly Quiz',
          ),
          testsRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polity Weekly Quiz'), findsWidgets);
    expect(find.text('Your score'), findsOneWidget);
    expect(find.text('14 / 20'), findsOneWidget);
    expect(find.textContaining('Attempt 2'), findsWidgets);
    expect(find.textContaining('70%'), findsWidgets);
    expect(find.textContaining('Grade B'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Score breakdown'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Score breakdown'), findsOneWidget);
    expect(find.text('Question 1 · 7 / 10'), findsOneWidget);
    expect(find.text('Clear structure and relevant examples.'), findsOneWidget);
    expect(find.text('accuracy'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Overall feedback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Overall feedback'), findsOneWidget);
    expect(
      find.text('Solid attempt with room to deepen concepts.'),
      findsOneWidget,
    );

    Future<void> reveal(String label) async {
      final finder = find.text(label, skipOffstage: false);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
    }

    await reveal('Strengths');
    expect(find.text('Structured answers', skipOffstage: false), findsOneWidget);
    await reveal('Weaknesses');
    await reveal('Improvement areas');
    expect(find.text('federalism', skipOffstage: false), findsOneWidget);
    await reveal('Actionable tips');
    expect(
      find.text('Define terms before arguing', skipOffstage: false),
      findsOneWidget,
    );
    await reveal('Improve answer with AI');
    expect(find.text('Done', skipOffstage: false), findsOneWidget);
  });

  testWidgets('S-46 shows empty-state when feedback missing', (tester) async {
    final fake = _FakeTests(
      const ResultFeedbackSnapshot(
        submission: SubmissionSummary(
          id: 'sub1',
          assessmentId: 'a1',
          status: 'evaluated',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ResultFeedbackScreen(
          args: const ResultFeedbackArgs(submissionId: 'sub1'),
          testsRepository: fake,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your score'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Question scores appear when AI evaluation finishes.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Question scores appear when AI evaluation finishes.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Detailed feedback appears after AI scoring completes.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Detailed feedback appears after AI scoring completes.'),
      findsOneWidget,
    );
  });
}
