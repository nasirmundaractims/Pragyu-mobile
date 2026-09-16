import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/tests/data/answer_media_uploader.dart';
import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/attempt_flow_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/deep_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/past_results_models.dart';
import 'package:student_mobile/features/tests/domain/result_feedback_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

abstract class TestsGateway {
  Future<TestsSnapshot> loadTests();

  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  );

  Future<AssessmentAttemptSession> startAttempt(String assessmentId);

  Future<SubmissionSummary> finalizeSubmission(String submissionId);

  Future<AttemptPlayerSnapshot> loadAttemptPlayer(AttemptPlayerArgs args);

  Future<void> updateSubmissionMetadata(
    String submissionId,
    Map<String, dynamic> metadata,
  );

  Future<SubmissionStatusPayload> getSubmissionStatus(String submissionId);

  Future<ResultFeedbackSnapshot> loadResultFeedback(ResultFeedbackArgs args);

  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args);

  Future<List<FeedbackSuggestionItem>> listSuggestions(String evaluationId);

  Future<List<FeedbackSuggestionItem>> generateSuggestions(String feedbackId);

  Future<RewriteRequestSummary> requestRewrite(
    String evaluationId,
    RewriteOptions options,
  );

  Future<RewriteRequestSummary?> getLatestRewrite(String evaluationId);

  Future<RewriteRequestSummary> getRewriteRequest(String rewriteRequestId);

  Future<RewriteResultPayload?> getRewriteResult(String rewriteRequestId);

  Future<RewriteRequestSummary> processRewrite(String rewriteRequestId);

  Future<AnswerImageAttachment> uploadAnswerImage({
    required String submissionId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int pageNumber,
  });

  Future<PastResultsSnapshot> loadPastResults();
}

class TestsRepository implements TestsGateway {
  TestsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
    AnswerMediaGateway? answerMediaUploader,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService(),
        _media = answerMediaUploader ?? AnswerMediaUploader();

  final ApiClient _api;
  final SessionService _session;
  final AnswerMediaGateway _media;

  @override
  Future<TestsSnapshot> loadTests() async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/assessments',
      query: const {
        'page': '1',
        'per_page': '50',
        'status': 'published',
        'sort': '-scheduled_at',
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) {
      return const TestsSnapshot();
    }

    final now = DateTime.now();
    final items = data
        .whereType<Map>()
        .map(
          (item) => TestListItem.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
            now: now,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);

    items.sort((a, b) {
      final rankA = _urgencyRank(a.due?.urgency);
      final rankB = _urgencyRank(b.due?.urgency);
      if (rankA != rankB) return rankA.compareTo(rankB);
      final da = a.deadlineAt ?? a.scheduledAt;
      final db = b.deadlineAt ?? b.scheduledAt;
      if (da == null && db == null) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return TestsSnapshot(items: items);
  }

  @override
  Future<AssessmentDetailSnapshot> loadAssessmentDetail(
    AssessmentDetailArgs args,
  ) async {
    final assessmentId = args.assessmentId.trim();
    if (assessmentId.isEmpty) {
      throw ArgumentError('assessmentId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/assessments/$assessmentId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = _asMap(envelope['data']);
    final assessment = AssessmentDetail.fromJson(data, now: DateTime.now());
    if (assessment.id.isEmpty) {
      throw StateError('Assessment not found.');
    }

    final profileId = await _loadStudentProfileId(session);
    if (profileId == null) {
      return AssessmentDetailSnapshot(assessment: assessment);
    }

    final attemptsFuture = _loadAttempts(
      session,
      assessmentId: assessmentId,
      studentProfileId: profileId,
    );
    final submissionsFuture = _loadSubmissions(
      session,
      assessmentId: assessmentId,
      studentProfileId: profileId,
    );
    final resultFuture = _loadFinalResult(
      session,
      assessmentId: assessmentId,
      studentProfileId: profileId,
    );

    final attempts = await attemptsFuture;
    final submissions = await submissionsFuture;
    final finalResult = await resultFuture;

    final activeAttempt = _pickActiveAttempt(attempts);
    final activeSubmission = _pickActiveSubmission(
      submissions,
      attemptId: activeAttempt?.id,
    );

    return AssessmentDetailSnapshot(
      assessment: assessment,
      studentProfileId: profileId,
      activeAttempt: activeAttempt,
      activeSubmission: activeSubmission,
      finalResult: finalResult,
    );
  }

  @override
  Future<AssessmentAttemptSession> startAttempt(String assessmentId) async {
    final id = assessmentId.trim();
    if (id.isEmpty) {
      throw ArgumentError('assessmentId is required');
    }

    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw StateError('Student profile is required to start this test.');
    }

    final attemptEnvelope = await _api.post(
      '/assessments/$id/attempts',
      body: {'student_profile_id': profileId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final attempt = AssessmentAttemptSummary.fromJson(
      _asMap(attemptEnvelope['data']),
    );
    if (attempt.id.isEmpty) {
      throw StateError('Unable to start attempt.');
    }

    final submissionEnvelope = await _api.post(
      '/submissions',
      body: {
        'assessment_id': id,
        'student_profile_id': profileId,
        'assessment_attempt_id': attempt.id,
        'attempt_number': attempt.attemptNumber,
        'metadata': const <String, dynamic>{},
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final submission = SubmissionSummary.fromJson(
      _asMap(submissionEnvelope['data']),
    );
    if (submission.id.isEmpty) {
      throw StateError('Unable to create submission draft.');
    }

    return AssessmentAttemptSession(
      attempt: attempt,
      submission: submission,
    );
  }

  @override
  Future<SubmissionSummary> finalizeSubmission(String submissionId) async {
    final id = submissionId.trim();
    if (id.isEmpty) {
      throw ArgumentError('submissionId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.post(
      '/submissions/$id/finalize',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return SubmissionSummary.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<AttemptPlayerSnapshot> loadAttemptPlayer(
    AttemptPlayerArgs args,
  ) async {
    final assessmentId = args.assessmentId.trim();
    final submissionId = args.submissionId.trim();
    final attemptId = args.attemptId.trim();
    if (assessmentId.isEmpty || submissionId.isEmpty) {
      throw ArgumentError('assessmentId and submissionId are required');
    }

    final detail = await loadAssessmentDetail(
      AssessmentDetailArgs(
        assessmentId: assessmentId,
        title: args.title,
      ),
    );
    final submission = await _getSubmission(submissionId);
    final metadata = submission.metadata;
    final answers = _parseAnswers(metadata['answers']);
    var player = CbtPlayerState.fromJson(metadata['player']);

    final questions = detail.assessment.questions;
    final firstId =
        questions.isEmpty ? null : questions.first.answerKey;
    final now = DateTime.now();
    final startedAt = player.startedAt ?? now;
    DateTime? deadlineAt = player.deadlineAt;
    final duration = detail.assessment.durationMinutes;
    if (deadlineAt == null && duration != null && duration > 0) {
      deadlineAt = startedAt.add(Duration(minutes: duration));
    }

    final currentId = player.currentQuestionId ?? firstId;
    final visited = {...player.visited};
    if (currentId != null && currentId.isNotEmpty) {
      visited.add(currentId);
    }

    player = player.copyWith(
      currentQuestionId: currentId,
      visited: visited.toList(growable: false),
      instructionsAcked: true,
      startedAt: startedAt,
      deadlineAt: deadlineAt,
    );

    return AttemptPlayerSnapshot(
      assessment: detail.assessment,
      questions: questions,
      answers: answers,
      player: player,
      submissionId: submissionId,
      attemptId: attemptId.isNotEmpty
          ? attemptId
          : (submission.assessmentAttemptId ?? ''),
    );
  }

  @override
  Future<void> updateSubmissionMetadata(
    String submissionId,
    Map<String, dynamic> metadata,
  ) async {
    final id = submissionId.trim();
    if (id.isEmpty) {
      throw ArgumentError('submissionId is required');
    }
    final session = await _requireSession();
    await _api.patch(
      '/submissions/$id',
      body: {'metadata': metadata},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<SubmissionStatusPayload> getSubmissionStatus(
    String submissionId,
  ) async {
    final id = submissionId.trim();
    if (id.isEmpty) {
      throw ArgumentError('submissionId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.get(
      '/submissions/$id/status',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return SubmissionStatusPayload.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<ResultFeedbackSnapshot> loadResultFeedback(
    ResultFeedbackArgs args,
  ) async {
    final submissionId = args.submissionId.trim();
    if (submissionId.isEmpty) {
      throw ArgumentError('submissionId is required');
    }

    final submission = await _getSubmission(submissionId);

    EvaluationSummary? evaluation;
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/submissions/$submissionId/evaluation',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final parsed = EvaluationSummary.fromJson(_asMap(envelope['data']));
      if (parsed.id.isNotEmpty) {
        evaluation = parsed;
      }
    } on ApiException {
      evaluation = null;
    } catch (_) {
      evaluation = null;
    }

    List<EvaluationScoreItem> scores = const [];
    EvaluationFeedbackReport? feedback;
    if (evaluation != null) {
      final evaluationId = evaluation.id;
      scores = await _loadEvaluationScores(evaluationId);
      feedback = await _loadEvaluationFeedback(evaluationId);
    }

    return ResultFeedbackSnapshot(
      submission: submission,
      evaluation: evaluation,
      scores: scores,
      feedback: feedback,
    );
  }

  @override
  Future<DeepFeedbackSnapshot> loadDeepFeedback(DeepFeedbackArgs args) async {
    final evaluationId = args.evaluationId.trim();
    if (evaluationId.isEmpty) {
      throw ArgumentError('evaluationId is required');
    }

    final submissionId = args.submissionId.trim();
    String? originalText;
    if (submissionId.isNotEmpty) {
      try {
        final submission = await _getSubmission(submissionId);
        originalText = extractOriginalAnswerText(submission.metadata);
      } catch (_) {
        originalText = null;
      }
    }

    final suggestions = await listSuggestions(evaluationId);
    final latest = await getLatestRewrite(evaluationId);
    RewriteResultPayload? result;
    if (latest != null && latest.id.isNotEmpty) {
      result = await getRewriteResult(latest.id);
    }

    return DeepFeedbackSnapshot(
      suggestions: suggestions,
      latestRewrite: latest,
      rewriteResult: result,
      originalAnswerText: originalText,
    );
  }

  @override
  Future<List<FeedbackSuggestionItem>> listSuggestions(
    String evaluationId,
  ) async {
    final id = evaluationId.trim();
    if (id.isEmpty) return const [];
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/evaluations/$id/suggestions',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseSuggestions(envelope['data']);
    } on ApiException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<FeedbackSuggestionItem>> generateSuggestions(
    String feedbackId,
  ) async {
    final id = feedbackId.trim();
    if (id.isEmpty) {
      throw ArgumentError('feedbackId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/feedback/$id/suggestions/generate',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return _parseSuggestions(envelope['data']);
  }

  @override
  Future<RewriteRequestSummary> requestRewrite(
    String evaluationId,
    RewriteOptions options,
  ) async {
    final id = evaluationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('evaluationId is required');
    }
    final session = await _requireSession();
    var body = options.toJson();
    if (options.studentProfileId == null ||
        options.studentProfileId!.isEmpty) {
      final profileId = await _loadStudentProfileId(session);
      if (profileId != null) {
        body = {
          ...body,
          'student_profile_id': profileId,
        };
      }
    }
    final envelope = await _api.post(
      '/evaluations/$id/rewrite',
      body: body,
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final request = RewriteRequestSummary.fromJson(_asMap(envelope['data']));
    if (request.id.isEmpty) {
      throw ApiException(
        message: 'Rewrite request did not return an id.',
        statusCode: 0,
      );
    }
    return request;
  }

  @override
  Future<RewriteRequestSummary?> getLatestRewrite(String evaluationId) async {
    final id = evaluationId.trim();
    if (id.isEmpty) return null;
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/evaluations/$id/rewrite',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data == null) return null;
      final request = RewriteRequestSummary.fromJson(_asMap(data));
      return request.id.isEmpty ? null : request;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RewriteRequestSummary> getRewriteRequest(
    String rewriteRequestId,
  ) async {
    final id = rewriteRequestId.trim();
    if (id.isEmpty) {
      throw ArgumentError('rewriteRequestId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.get(
      '/rewrite-requests/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return RewriteRequestSummary.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<RewriteResultPayload?> getRewriteResult(
    String rewriteRequestId,
  ) async {
    final id = rewriteRequestId.trim();
    if (id.isEmpty) return null;
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/rewrite-requests/$id/result',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data == null) return null;
      final result = RewriteResultPayload.fromJson(_asMap(data));
      return result.hasRewrittenText || result.id.isNotEmpty ? result : null;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RewriteRequestSummary> processRewrite(
    String rewriteRequestId,
  ) async {
    final id = rewriteRequestId.trim();
    if (id.isEmpty) {
      throw ArgumentError('rewriteRequestId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/rewrite-requests/$id/process',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return RewriteRequestSummary.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<PastResultsSnapshot> loadPastResults() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      return const PastResultsSnapshot();
    }

    final submissionsFuture = _loadAllSubmissions(
      session,
      studentProfileId: profileId,
    );
    final testsFuture = loadTests();
    final submissions = await submissionsFuture;
    final tests = await testsFuture;

    final titles = <String, String>{
      for (final test in tests.items) test.id: test.title,
    };

    return PastResultsSnapshot(
      submissions: submissions,
      assessmentTitles: titles,
    );
  }

  Future<List<SubmissionSummary>> _loadAllSubmissions(
    SessionContext session, {
    required String studentProfileId,
  }) async {
    try {
      final envelope = await _api.get(
        '/submissions',
        query: {
          'page': '1',
          'per_page': '50',
          'student_profile_id': studentProfileId,
          'sort': '-submitted_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => SubmissionSummary.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty && !item.isDraft)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AnswerImageAttachment> uploadAnswerImage({
    required String submissionId,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    required int pageNumber,
  }) {
    return _media.uploadAnswerImage(
      submissionId: submissionId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      pageNumber: pageNumber,
    );
  }

  List<FeedbackSuggestionItem> _parseSuggestions(Object? data) {
    List<dynamic>? rows;
    if (data is List) {
      rows = data;
    } else if (data is Map) {
      final map = data.map((k, v) => MapEntry(k.toString(), v));
      final items = map['items'] ?? map['suggestions'] ?? map['data'];
      if (items is List) rows = items;
    }
    if (rows == null) return const [];

    final items = rows
        .whereType<Map>()
        .map(
          (item) => FeedbackSuggestionItem.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .where((item) => item.id.isNotEmpty || item.headline.isNotEmpty)
        .toList(growable: false);
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<List<EvaluationScoreItem>> _loadEvaluationScores(
    String evaluationId,
  ) async {
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/evaluations/$evaluationId/scores',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => EvaluationScoreItem.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<EvaluationFeedbackReport?> _loadEvaluationFeedback(
    String evaluationId,
  ) async {
    try {
      final session = await _requireSession();
      final envelope = await _api.get(
        '/evaluations/$evaluationId/feedback',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final report = EvaluationFeedbackReport.fromJson(
        _asMap(envelope['data']),
      );
      return report.id.isEmpty ? null : report;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<SubmissionSummary> _getSubmission(String submissionId) async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/submissions/$submissionId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return SubmissionSummary.fromJson(_asMap(envelope['data']));
  }

  static Map<String, StudentAnswerValue> _parseAnswers(Object? raw) {
    if (raw is! Map) return {};
    final out = <String, StudentAnswerValue>{};
    raw.forEach((key, value) {
      if (value is Map) {
        out[key.toString()] = StudentAnswerValue.fromJson(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    });
    return out;
  }

  Future<List<AssessmentAttemptSummary>> _loadAttempts(
    SessionContext session, {
    required String assessmentId,
    required String studentProfileId,
  }) async {
    try {
      final envelope = await _api.get(
        '/assessment-attempts',
        query: {
          'page': '1',
          'per_page': '20',
          'assessment_id': assessmentId,
          'student_profile_id': studentProfileId,
          'sort': '-created_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => AssessmentAttemptSummary.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SubmissionSummary>> _loadSubmissions(
    SessionContext session, {
    required String assessmentId,
    required String studentProfileId,
  }) async {
    try {
      final envelope = await _api.get(
        '/assessments/$assessmentId/submissions',
        query: {
          'page': '1',
          'per_page': '20',
          'student_profile_id': studentProfileId,
          'sort': '-created_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => SubmissionSummary.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<FinalResultSummary?> _loadFinalResult(
    SessionContext session, {
    required String assessmentId,
    required String studentProfileId,
  }) async {
    try {
      final envelope = await _api.get(
        '/assessments/$assessmentId/final-results/me',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      if (data.isEmpty) return null;
      final result = FinalResultSummary.fromJson(data);
      return result.id.isEmpty ? null : result;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _loadStudentProfileId(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final id = data['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  AssessmentAttemptSummary? _pickActiveAttempt(
    List<AssessmentAttemptSummary> attempts,
  ) {
    for (final attempt in attempts) {
      if (attempt.isActive) return attempt;
    }
    return null;
  }

  SubmissionSummary? _pickActiveSubmission(
    List<SubmissionSummary> submissions, {
    String? attemptId,
  }) {
    if (attemptId != null && attemptId.isNotEmpty) {
      for (final submission in submissions) {
        if (submission.isDraft &&
            submission.assessmentAttemptId == attemptId) {
          return submission;
        }
      }
    }
    for (final submission in submissions) {
      if (submission.isDraft) return submission;
    }
    return null;
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static int _urgencyRank(DueUrgency? urgency) {
    switch (urgency) {
      case DueUrgency.endsSoon:
        return 0;
      case DueUrgency.overdue:
        return 1;
      case DueUrgency.dueToday:
        return 2;
      case DueUrgency.dueTomorrow:
        return 3;
      case DueUrgency.none:
      case null:
        return 9;
    }
  }
}
