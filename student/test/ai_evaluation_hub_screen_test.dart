import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/ai_answer_upload_models.dart';
import 'package:student_mobile/features/tests/domain/ai_evaluation_hub_models.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';
import 'package:student_mobile/features/tests/presentation/screens/ai_answer_upload_screen.dart';
import 'package:student_mobile/features/tests/presentation/screens/ai_evaluation_hub_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests({
    this.tests = const TestsSnapshot(),
    this.past = const PastResultsSnapshot(),
    this.details = const {},
  });

  final TestsSnapshot tests;
  final PastResultsSnapshot past;
  final Map<String, AssessmentDetailSnapshot> details;

  @override
  Future<TestsSnapshot> loadTests({int page = 1}) async => tests;

  @override
  Future<PastResultsSnapshot> loadPastResults() async => past;

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    final detail = details[args.assessmentId];
    if (detail != null) return detail;
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
  Future<List<FeedbackSuggestionItem>> listSuggestions(
    String evaluationId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(
    String feedbackId,
  ) async {
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
  Future<RewriteRequestSummary> getRewriteRequest(
    String rewriteRequestId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(
    String rewriteRequestId,
  ) async {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  test('2.2 short/long labels and primary CTAs are explicit', () {
    const short = AiEvalQuestionItem(
      assessmentId: 'a1',
      assessmentTitle: 'Polity',
      question: AssessmentQuestionPreview(
        id: 'q1',
        sortOrder: 1,
        type: 'short_answer',
        content: 'Define preamble',
      ),
      questionIndex: 0,
      questionTotal: 1,
      kind: AiAnswerKind.shortAnswer,
      status: AiEvalQuestionStatus.notStarted,
    );
    const long = AiEvalQuestionItem(
      assessmentId: 'a1',
      assessmentTitle: 'Polity',
      question: AssessmentQuestionPreview(
        id: 'q2',
        sortOrder: 2,
        type: 'essay',
        content: 'Discuss judicial review',
      ),
      questionIndex: 1,
      questionTotal: 2,
      kind: AiAnswerKind.longAnswer,
      status: AiEvalQuestionStatus.evaluated,
    );
    const failed = AiEvalQuestionItem(
      assessmentId: 'a1',
      assessmentTitle: 'Polity',
      question: AssessmentQuestionPreview(
        id: 'q3',
        sortOrder: 3,
        type: 'essay',
        content: 'Failed item',
      ),
      questionIndex: 2,
      questionTotal: 3,
      kind: AiAnswerKind.longAnswer,
      status: AiEvalQuestionStatus.failed,
    );

    expect(short.kindLabel, 'Short answer');
    expect(short.kindHint, contains('Concise'));
    expect(short.primaryActionLabel, 'Upload answer');
    expect(long.kindLabel, 'Long answer');
    expect(long.kindHint, contains('Essay'));
    expect(long.primaryActionLabel, 'View score');
    expect(long.canReattempt, isTrue);
    expect(failed.primaryActionLabel, 'Upload again');
  });

  testWidgets('2.2 hub empty state guides to Practice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiEvaluationHubScreen(
          testsRepository: _FakeTests(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No AI evaluation questions yet'), findsOneWidget);
    expect(find.text('Go to Practice'), findsOneWidget);
    expect(find.textContaining('Short answer = concise'), findsOneWidget);
  });

  testWidgets('2.2 hub shows short/long clarity and upload CTA', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fake = _FakeTests(
      tests: const TestsSnapshot(
        items: [
          TestListItem(
            id: 'a1',
            title: 'AI Evaluation Polity',
            type: TestKind.assignment,
          ),
        ],
      ),
      details: {
        'a1': const AssessmentDetailSnapshot(
          assessment: AssessmentDetail(
            id: 'a1',
            title: 'AI Evaluation Polity',
            questions: [
              AssessmentQuestionPreview(
                id: 'q1',
                sortOrder: 1,
                type: 'short_answer',
                content: 'Define preamble in two lines.',
                maxMarks: 5,
                subjectName: 'Polity',
                allowsImageUpload: true,
              ),
              AssessmentQuestionPreview(
                id: 'q2',
                sortOrder: 2,
                type: 'essay',
                content: 'Discuss judicial review with examples.',
                maxMarks: 10,
                subjectName: 'Polity',
                allowsImageUpload: true,
              ),
            ],
          ),
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiEvaluationHubScreen(testsRepository: fake),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Short answer'), findsWidgets);
    expect(find.text('Long answer'), findsWidgets);
    expect(find.text('Concise written response'), findsOneWidget);
    expect(find.text('Essay / descriptive response'), findsOneWidget);
    expect(find.text('Upload answer'), findsWidgets);

    await tester.tap(find.text('Short answer').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('concise written questions only'), findsOneWidget);
    expect(find.textContaining('Define preamble'), findsOneWidget);
    expect(find.textContaining('judicial review'), findsNothing);
  });

  testWidgets('2.2 multi-question upload submit copy is honest', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AiAnswerUploadScreen(
          args: const AiAnswerUploadArgs(
            submissionId: 'sub-1',
            assessmentId: 'asm-1',
            questionIndex: 0,
            questionTotal: 3,
            finalizeOnSubmit: true,
            question: AssessmentQuestionPreview(
              id: 'q1',
              sortOrder: 1,
              maxMarks: 5,
              type: 'short_answer',
              content: 'Define preamble',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Short answer'), findsWidgets);
    expect(find.text('Submit all answers for AI'), findsOneWidget);
  });
}
