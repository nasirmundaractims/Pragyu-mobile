import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

/// Route args for S-45 Submission status.
class SubmissionStatusArgs {
  const SubmissionStatusArgs({
    required this.submissionId,
    this.assessmentId,
    this.title,
    this.initialStatus,
    this.includesMedia = false,
  });

  final String submissionId;
  final String? assessmentId;
  final String? title;
  final String? initialStatus;
  final bool includesMedia;

  factory SubmissionStatusArgs.fromObject(Object? raw) {
    if (raw is SubmissionStatusArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return SubmissionStatusArgs(
        submissionId: map['submissionId']?.toString() ??
            map['submission_id']?.toString() ??
            map['id']?.toString() ??
            '',
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString(),
        title: map['title']?.toString(),
        initialStatus: map['initialStatus']?.toString() ??
            map['initial_status']?.toString() ??
            map['status']?.toString(),
        includesMedia: map['includesMedia'] == true ||
            map['includes_media'] == true,
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return SubmissionStatusArgs(submissionId: raw);
    }
    return const SubmissionStatusArgs(submissionId: '');
  }
}

/// Compact payload from GET /submissions/{id}/status.
class SubmissionStatusPayload {
  const SubmissionStatusPayload({
    required this.id,
    required this.status,
    this.submittedAt,
    this.failureReason,
  });

  final String id;
  final String status;
  final DateTime? submittedAt;
  final String? failureReason;

  bool get isTerminal =>
      SubmissionPipeline.isReady(status) || SubmissionPipeline.isFailed(status);

  bool get isPending => SubmissionPipeline.isPending(status);

  String get statusLabel => submissionStatusLabel(status);

  bool get isOcrStage {
    switch (status.toLowerCase()) {
      case 'media_processing':
      case 'ocr_processing':
        return true;
      default:
        return false;
    }
  }

  factory SubmissionStatusPayload.fromJson(Map<String, dynamic> json) {
    return SubmissionStatusPayload(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      submittedAt: _parseDate(json['submitted_at']?.toString()),
      failureReason: _nullableTrim(json['failure_reason']?.toString()),
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String? _nullableTrim(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

/// Route args for S-46 Result / feedback.
class ResultFeedbackArgs {
  const ResultFeedbackArgs({
    required this.submissionId,
    this.assessmentId,
    this.title,
    this.initialScoreIndex = 0,
  });

  final String submissionId;
  final String? assessmentId;
  final String? title;
  final int initialScoreIndex;

  factory ResultFeedbackArgs.fromObject(Object? raw) {
    if (raw is ResultFeedbackArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final indexRaw = map['initialScoreIndex'] ?? map['initial_score_index'];
      final parsedIndex = indexRaw is num
          ? indexRaw.round()
          : int.tryParse(indexRaw?.toString() ?? '') ?? 0;
      return ResultFeedbackArgs(
        submissionId: map['submissionId']?.toString() ??
            map['submission_id']?.toString() ??
            map['id']?.toString() ??
            '',
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString(),
        title: map['title']?.toString(),
        initialScoreIndex: parsedIndex < 0 ? 0 : parsedIndex,
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return ResultFeedbackArgs(submissionId: raw);
    }
    return const ResultFeedbackArgs(submissionId: '');
  }
}

enum SubmissionPipelineStage {
  /// Media / OCR / initial processing.
  processing,

  /// Waiting in AI queue (`ready_for_evaluation`).
  queued,

  /// AI scoring in progress (`evaluating`).
  evaluating,

  ready,
  failed,
}

abstract final class SubmissionPipeline {
  static bool isPending(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'media_processing':
      case 'ocr_processing':
      case 'ready_for_evaluation':
      case 'evaluating':
        return true;
      default:
        return false;
    }
  }

  static bool isReady(String status) => status.toLowerCase() == 'evaluated';

  static bool isFailed(String status) {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'partially_failed':
        return true;
      default:
        return false;
    }
  }

  static bool isQueued(String status) =>
      status.toLowerCase() == 'ready_for_evaluation';

  static bool isEvaluating(String status) =>
      status.toLowerCase() == 'evaluating';

  static bool hasFailureReason(String? failureReason) =>
      failureReason != null && failureReason.trim().isNotEmpty;

  /// Pending statuses that still carry a server `failure_reason` need a
  /// blocked UI (not an endless spinner).
  static bool isBlocked(String status, String? failureReason) =>
      isPending(status) && hasFailureReason(failureReason);

  static SubmissionPipelineStage stageFor(String status) {
    final value = status.toLowerCase();
    if (isFailed(value)) return SubmissionPipelineStage.failed;
    if (isReady(value)) return SubmissionPipelineStage.ready;
    switch (value) {
      case 'ready_for_evaluation':
        return SubmissionPipelineStage.queued;
      case 'evaluating':
        return SubmissionPipelineStage.evaluating;
      default:
        return SubmissionPipelineStage.processing;
    }
  }

  /// Short student-facing phase name for the hero.
  static String phaseTitle(String status, {String? failureReason}) {
    if (isFailed(status)) return 'Evaluation failed';
    if (isReady(status)) return 'Feedback ready';
    if (isBlocked(status, failureReason)) return 'Waiting on a fix';
    switch (status.toLowerCase()) {
      case 'media_processing':
      case 'ocr_processing':
        return 'Reading your pages';
      case 'ready_for_evaluation':
        return 'Queued for AI';
      case 'evaluating':
        return 'AI evaluating';
      case 'pending':
        return 'Submitted';
      default:
        return submissionStatusLabel(status);
    }
  }
}

extension SubmissionStatusPayloadHonesty on SubmissionStatusPayload {
  bool get isQueued => SubmissionPipeline.isQueued(status);

  bool get isEvaluating => SubmissionPipeline.isEvaluating(status);

  bool get isBlocked => SubmissionPipeline.isBlocked(status, failureReason);

  String get phaseTitle =>
      SubmissionPipeline.phaseTitle(status, failureReason: failureReason);
}

extension SubmissionSummaryStatusX on SubmissionSummary {
  String get pipelineLabel => submissionStatusLabel(status);

  bool get isPipelinePending => SubmissionPipeline.isPending(status);

  bool get isPipelineReady => SubmissionPipeline.isReady(status);

  bool get isPipelineFailed => SubmissionPipeline.isFailed(status);
}
