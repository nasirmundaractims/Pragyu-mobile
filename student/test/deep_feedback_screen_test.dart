import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/deep_feedback_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests({
    required this.snapshot,
    this.request,
  });

  final DeepFeedbackSnapshot snapshot;
  final RewriteRequestSummary? request;
  int requestCalls = 0;

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
    throw UnimplementedError();
  }

  @override
  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args) async {
    return snapshot;
  }

  @override
  Future<List<FeedbackSuggestionItem>> listSuggestions(
    String evaluationId,
  ) async {
    return snapshot.suggestions;
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(
    String feedbackId,
  ) async {
    return const [
      FeedbackSuggestionItem(
        id: 'gen1',
        title: 'Generated tip',
        description: 'Practice federalism definitions.',
      ),
    ];
  }

  @override
  Future<RewriteRequestSummary> requestRewrite(
    String evaluationId,
    RewriteOptions options,
  ) async {
    requestCalls += 1;
    return request ??
        const RewriteRequestSummary(
          id: 'rw1',
          evaluationId: 'ev1',
          status: 'processing',
        );
  }

  @override
  Future<RewriteRequestSummary?> getLatestRewrite(String evaluationId) async {
    return snapshot.latestRewrite;
  }

  @override
  Future<RewriteRequestSummary> getRewriteRequest(
    String rewriteRequestId,
  ) async {
    return request ??
        const RewriteRequestSummary(
          id: 'rw1',
          evaluationId: 'ev1',
          status: 'completed',
        );
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(
    String rewriteRequestId,
  ) async {
    return snapshot.rewriteResult;
  }

  @override
  Future<RewriteRequestSummary> processRewrite(
    String rewriteRequestId,
  ) async {
    return const RewriteRequestSummary(
      id: 'rw1',
      evaluationId: 'ev1',
      status: 'processing',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('extractOriginalAnswerText joins metadata answers', () {
    final text = extractOriginalAnswerText({
      'answers': {
        'q1': {'text': 'Federalism divides power.'},
        'q2': {'answer': 'India is a union of states.'},
      },
    });
    expect(text, contains('Federalism divides power.'));
    expect(text, contains('India is a union of states.'));
  });

  testWidgets('S-47 shows suggestions and completed rewrite', (tester) async {
    final fake = _FakeTests(
      snapshot: const DeepFeedbackSnapshot(
        suggestions: [
          FeedbackSuggestionItem(
            id: 'sg1',
            category: 'content',
            title: 'Define key terms first',
            description: 'Open with a crisp definition of federalism.',
          ),
        ],
        latestRewrite: RewriteRequestSummary(
          id: 'rw1',
          evaluationId: 'ev1',
          status: 'completed',
        ),
        rewriteResult: RewriteResultPayload(
          id: 'res1',
          rewriteRequestId: 'rw1',
          rewrittenText: 'Federalism is a division of powers…',
          modelAnswer: 'Ideal model answer about federalism.',
          disclaimer: 'AI-generated rewrite for study purposes.',
          improvementItems: ['Added definition upfront'],
          reasoning: 'Stronger opening improves clarity.',
        ),
        originalAnswerText: 'Federalism divides power between centre and states.',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DeepFeedbackScreen(
          args: const DeepFeedbackArgs(
            submissionId: 'sub1',
            evaluationId: 'ev1',
            feedbackId: 'fb1',
            title: 'Polity Weekly Quiz',
          ),
          testsRepository: fake,
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polity Weekly Quiz'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Define key terms first'), findsOneWidget);

    Future<void> reveal(String label) async {
      final finder = find.text(label, skipOffstage: false);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsWidgets);
    }

    await reveal('Improve answer with AI');
    await reveal('Your answer');
    expect(
      find.text(
        'Federalism divides power between centre and states.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await reveal('AI improved answer');
    expect(
      find.text('Federalism is a division of powers…', skipOffstage: false),
      findsOneWidget,
    );
    await reveal('Model answer');
    expect(
      find.text('Ideal model answer about federalism.', skipOffstage: false),
      findsOneWidget,
    );
    await reveal('What changed');
    await reveal('Why this rewrite');
    expect(find.text('Back to result', skipOffstage: false), findsOneWidget);
  });

  testWidgets('S-47 empty suggestions can generate', (tester) async {
    final fake = _FakeTests(
      snapshot: const DeepFeedbackSnapshot(
        originalAnswerText: 'Short answer',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: DeepFeedbackScreen(
          args: const DeepFeedbackArgs(
            submissionId: 'sub1',
            evaluationId: 'ev1',
            feedbackId: 'fb1',
          ),
          testsRepository: fake,
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No personalized suggestions yet.'), findsOneWidget);
    await tester.tap(find.text('Generate suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('Generated tip'), findsOneWidget);
  });
}
