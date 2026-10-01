import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:student_mobile/app/theme/app_theme.dart';
import 'package:student_mobile/core/config/app_config.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/features/tests/data/tests_repository.dart';
import 'package:student_mobile/features/tests/domain/ai_answer_upload_models.dart';
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
import 'package:student_mobile/features/tests/presentation/screens/result_feedback_screen.dart';

/// Slice 0.4 — cold-start smoke for AI hub / result / upload (empty + loaded).
class _SmokeTests implements TestsGateway {
  _SmokeTests({
    this.tests = const TestsSnapshot(),
    this.pastResults = const PastResultsSnapshot(),
    this.details = const {},
    this.result,
    this.resultError,
    this.testsError,
  });

  final TestsSnapshot tests;
  final PastResultsSnapshot pastResults;
  final Map<String, AssessmentDetailSnapshot> details;
  final ResultFeedbackSnapshot? result;
  final Object? resultError;
  final Object? testsError;

  @override
  Future<TestsSnapshot> loadTests({int page = 1}) async {
    if (testsError != null) throw testsError!;
    return tests;
  }

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    final detail = details[args.assessmentId];
    if (detail == null) {
      throw ApiException(message: 'not found', statusCode: 404);
    }
    return detail;
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
    if (resultError != null) throw resultError!;
    return result ??
        const ResultFeedbackSnapshot(
          submission: SubmissionSummary(id: 'sub', assessmentId: 'a'),
        );
  }

  @override
  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args) async {
    throw UnimplementedError();
  }

  @override
  Future<List<FeedbackSuggestionItem>> listSuggestions(
    String evaluationId,
  ) async {
    return const [];
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(
    String feedbackId,
  ) async {
    return const [];
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
    return null;
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
    return null;
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
  Future<PastResultsSnapshot> loadPastResults() async => pastResults;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppConfig.load();
  });

  Future<void> pumpSmoke(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: home,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('AI Evaluation hub smoke', () {
    testWidgets('empty catalog does not crash', (tester) async {
      await pumpSmoke(
        tester,
        AiEvaluationHubScreen(testsRepository: _SmokeTests()),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Evaluation'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loaded short/long questions do not crash', (tester) async {
      const assessmentId = 'ai-1';
      final fake = _SmokeTests(
        tests: const TestsSnapshot(
          items: [
            TestListItem(
              id: assessmentId,
              title: 'AI Evaluation Essay',
              type: TestKind.assignment,
            ),
          ],
        ),
        details: {
          assessmentId: AssessmentDetailSnapshot(
            assessment: AssessmentDetail(
              id: assessmentId,
              title: 'AI Evaluation Essay',
              type: TestKind.assignment,
              questions: const [
                AssessmentQuestionPreview(
                  id: 'q1',
                  sortOrder: 1,
                  type: 'short_text',
                  content: 'Define preamble in one sentence.',
                  maxMarks: 2,
                  subjectName: 'Polity',
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

      await pumpSmoke(
        tester,
        AiEvaluationHubScreen(testsRepository: fake),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('question'), findsWidgets);
      expect(find.textContaining('Define preamble'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('load error does not crash', (tester) async {
      await pumpSmoke(
        tester,
        AiEvaluationHubScreen(
          testsRepository: _SmokeTests(
            testsError: ApiException(message: 'offline', statusCode: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('offline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Result feedback smoke', () {
    testWidgets('empty scores + huge initial index do not crash', (tester) async {
      await pumpSmoke(
        tester,
        ResultFeedbackScreen(
          args: const ResultFeedbackArgs(
            submissionId: 'sub1',
            title: 'Empty result',
            initialScoreIndex: 99,
          ),
          testsRepository: _SmokeTests(
            result: const ResultFeedbackSnapshot(
              submission: SubmissionSummary(
                id: 'sub1',
                assessmentId: 'a1',
                status: 'evaluated',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overall Score'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loaded multi-score result does not crash', (tester) async {
      await pumpSmoke(
        tester,
        ResultFeedbackScreen(
          args: const ResultFeedbackArgs(
            submissionId: 'sub1',
            title: 'Polity Essay',
            initialScoreIndex: 1,
          ),
          testsRepository: _SmokeTests(
            result: ResultFeedbackSnapshot(
              submission: const SubmissionSummary(
                id: 'sub1',
                assessmentId: 'a1',
                attemptNumber: 1,
                status: 'evaluated',
                totalScore: 12,
                maxScore: 20,
                percentage: 60,
              ),
              evaluation: const EvaluationSummary(
                id: 'ev1',
                submissionId: 'sub1',
                assessmentId: 'a1',
                totalScore: 12,
                maxScore: 20,
                percentage: 60,
              ),
              scores: const [
                EvaluationScoreItem(
                  id: 's1',
                  scoreAwarded: 5,
                  maxScore: 10,
                  feedback: 'Okay',
                ),
                EvaluationScoreItem(
                  id: 's2',
                  scoreAwarded: 7,
                  maxScore: 10,
                  feedback: 'Better',
                ),
              ],
              feedback: const EvaluationFeedbackReport(
                id: 'fb1',
                evaluationId: 'ev1',
                summary: 'Keep practicing.',
                strengths: ['Structure'],
                weaknesses: ['Examples'],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12 / 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('result load error does not crash', (tester) async {
      await pumpSmoke(
        tester,
        ResultFeedbackScreen(
          args: const ResultFeedbackArgs(submissionId: 'sub1'),
          testsRepository: _SmokeTests(
            resultError: ApiException(message: 'gone', statusCode: 404),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('gone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AI answer upload smoke', () {
    testWidgets('minimal empty question does not crash', (tester) async {
      await pumpSmoke(
        tester,
        const AiAnswerUploadScreen(
          args: AiAnswerUploadArgs(
            submissionId: 'sub',
            assessmentId: 'a1',
            questionIndex: 0,
            questionTotal: 1,
            finalizeOnSubmit: true,
            question: AssessmentQuestionPreview(
              id: 'q1',
              sortOrder: 1,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Upload Answer for Question'), findsOneWidget);
      expect(find.text('Submit for AI Evaluation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('existing images list does not crash', (tester) async {
      await pumpSmoke(
        tester,
        AiAnswerUploadScreen(
          args: AiAnswerUploadArgs(
            submissionId: 'sub',
            assessmentId: 'a1',
            questionIndex: 0,
            questionTotal: 2,
            tags: const ['Short answer', 'Polity'],
            question: const AssessmentQuestionPreview(
              id: 'q1',
              sortOrder: 1,
              type: 'essay',
              content: 'Explain federalism.',
              maxMarks: 10,
            ),
            existingImages: const [
              AnswerImageAttachment(
                mediaFileId: 'm1',
                fileName: 'page-1.jpg',
                pageNumber: 1,
                url: '',
                uploadedAt: '2026-10-01T00:00:00Z',
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Uploaded Pages'), findsOneWidget);
      expect(find.text('page-1.jpg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
