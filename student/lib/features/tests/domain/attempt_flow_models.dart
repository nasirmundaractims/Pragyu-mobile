import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

/// Route args for S-42 Attempt instructions.
class AttemptInstructionsArgs {
  const AttemptInstructionsArgs({
    required this.assessmentId,
    this.title,
    this.attemptId,
    this.submissionId,
  });

  final String assessmentId;
  final String? title;
  final String? attemptId;
  final String? submissionId;

  bool get hasOpenSession =>
      (attemptId?.trim().isNotEmpty ?? false) &&
      (submissionId?.trim().isNotEmpty ?? false);

  factory AttemptInstructionsArgs.fromObject(Object? raw) {
    if (raw is AttemptInstructionsArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return AttemptInstructionsArgs(
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString() ??
            map['id']?.toString() ??
            '',
        title: map['title']?.toString(),
        attemptId: map['attemptId']?.toString() ??
            map['attempt_id']?.toString(),
        submissionId: map['submissionId']?.toString() ??
            map['submission_id']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return AttemptInstructionsArgs(assessmentId: raw);
    }
    return const AttemptInstructionsArgs(assessmentId: '');
  }
}

/// Route args for S-43 Attempt player (stub until CBT ships).
class AttemptPlayerArgs {
  const AttemptPlayerArgs({
    required this.assessmentId,
    required this.attemptId,
    required this.submissionId,
    this.title,
  });

  final String assessmentId;
  final String attemptId;
  final String submissionId;
  final String? title;

  factory AttemptPlayerArgs.fromObject(Object? raw) {
    if (raw is AttemptPlayerArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return AttemptPlayerArgs(
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString() ??
            '',
        attemptId: map['attemptId']?.toString() ??
            map['attempt_id']?.toString() ??
            '',
        submissionId: map['submissionId']?.toString() ??
            map['submission_id']?.toString() ??
            '',
        title: map['title']?.toString(),
      );
    }
    return const AttemptPlayerArgs(
      assessmentId: '',
      attemptId: '',
      submissionId: '',
    );
  }

  factory AttemptPlayerArgs.fromSession({
    required String assessmentId,
    required AssessmentAttemptSession session,
    String? title,
  }) {
    return AttemptPlayerArgs(
      assessmentId: assessmentId,
      attemptId: session.attempt.id,
      submissionId: session.submission.id,
      title: title,
    );
  }
}
