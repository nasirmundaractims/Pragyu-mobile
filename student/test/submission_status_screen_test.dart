import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/router/app_router.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/submission_status_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests(this.statuses);

  final List<SubmissionStatusPayload> statuses;
  int calls = 0;

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
    final index = calls.clamp(0, statuses.length - 1);
    calls += 1;
    return statuses[index];
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

  testWidgets('S-45 polls until feedback ready then opens S-46', (tester) async {
    Object? resultArgs;
    final fake = _FakeTests([
      const SubmissionStatusPayload(
        id: 'sub1',
        status: 'evaluating',
      ),
      const SubmissionStatusPayload(
        id: 'sub1',
        status: 'evaluated',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SubmissionStatusScreen(
          args: const SubmissionStatusArgs(
            submissionId: 'sub1',
            assessmentId: 'a1',
            title: 'Polity Weekly Quiz',
            initialStatus: 'ready_for_evaluation',
          ),
          testsRepository: fake,
          pollInterval: const Duration(milliseconds: 20),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.resultFeedback) {
            resultArgs = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Result feedback')),
            );
          }
          return null;
        },
      ),
    );

    // First status fetch (avoid pumpAndSettle — it would drain the poll timer).
    await tester.pump();
    await tester.pump();

    expect(find.text('Polity Weekly Quiz'), findsOneWidget);
    // Hero label + pipeline step share this copy.
    expect(find.text('AI evaluating'), findsAtLeastNWidgets(1));
    expect(find.text('Checking for updates…'), findsOneWidget);

    // Fire scheduled poll → second status (evaluated).
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pump();

    expect(find.text('Feedback ready'), findsOneWidget);
    expect(find.text('View result'), findsOneWidget);

    await tester.tap(find.text('View result'));
    await tester.pumpAndSettle();

    expect(find.text('Result feedback'), findsOneWidget);
    expect(resultArgs, isA<ResultFeedbackArgs>());
    expect((resultArgs! as ResultFeedbackArgs).submissionId, 'sub1');
    expect(fake.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('S-45 shows failed state', (tester) async {
    final fake = _FakeTests([
      const SubmissionStatusPayload(
        id: 'sub1',
        status: 'failed',
        failureReason: 'OCR could not read the pages.',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SubmissionStatusScreen(
          args: const SubmissionStatusArgs(
            submissionId: 'sub1',
            initialStatus: 'failed',
          ),
          testsRepository: fake,
          pollInterval: const Duration(hours: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('OCR could not read the pages.'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });
}
