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
import 'package:student_mobile/features/tests/presentation/screens/submission_status_screen.dart';

class _FakeTests implements TestsGateway {
  _FakeTests(this.payload);

  final SubmissionStatusPayload payload;

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
    return payload;
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
  testWidgets('S-45 shows OCR pipeline for media submissions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: SubmissionStatusScreen(
          args: const SubmissionStatusArgs(
            submissionId: 'sub1',
            title: 'Essay test',
            initialStatus: 'ocr_processing',
            includesMedia: true,
          ),
          testsRepository: _FakeTests(
            const SubmissionStatusPayload(
              id: 'sub1',
              status: 'ocr_processing',
            ),
          ),
          pollInterval: const Duration(days: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'Your handwritten pages are being read with OCR before AI scoring.',
      ),
      findsOneWidget,
    );
    expect(find.text('OCR reading pages'), findsOneWidget);
  });
}
