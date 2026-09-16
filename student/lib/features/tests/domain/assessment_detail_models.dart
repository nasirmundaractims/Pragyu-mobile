import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/tests/domain/tests_models.dart';

String submissionStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'draft':
      return 'Draft';
    case 'pending':
      return 'Submitted';
    case 'media_processing':
    case 'ocr_processing':
      return 'OCR in progress';
    case 'ready_for_evaluation':
      return 'Queued for AI';
    case 'evaluating':
      return 'AI evaluating';
    case 'evaluated':
      return 'Feedback ready';
    case 'failed':
    case 'partially_failed':
      return 'Needs attention';
    case 'archived':
      return 'Archived';
    default:
      return status.replaceAll('_', ' ');
  }
}

/// Route args for S-41 Assessment detail.
class AssessmentDetailArgs {
  const AssessmentDetailArgs({
    required this.assessmentId,
    this.title,
  });

  final String assessmentId;
  final String? title;

  factory AssessmentDetailArgs.fromObject(Object? raw) {
    if (raw is AssessmentDetailArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return AssessmentDetailArgs(
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString() ??
            map['id']?.toString() ??
            '',
        title: map['title']?.toString(),
      );
    }
    if (raw is String && raw.isNotEmpty) {
      return AssessmentDetailArgs(assessmentId: raw);
    }
    return const AssessmentDetailArgs(assessmentId: '');
  }
}

class AnswerChoice {
  const AnswerChoice({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class AssessmentQuestionPreview {
  const AssessmentQuestionPreview({
    required this.id,
    this.questionId,
    required this.sortOrder,
    this.content,
    this.maxMarks,
    this.type,
    this.choices = const [],
    this.wordLimit,
    this.allowsImageUpload = false,
  });

  /// Assessment-question link id (row id).
  final String id;

  /// Source question id used as answer / player map keys.
  final String? questionId;
  final int sortOrder;
  final String? content;
  final double? maxMarks;
  final String? type;
  final List<AnswerChoice> choices;
  final int? wordLimit;
  final bool allowsImageUpload;

  String get answerKey {
    final source = questionId?.trim();
    if (source != null && source.isNotEmpty) return source;
    return id.trim();
  }

  List<AnswerChoice> get effectiveChoices {
    if (choices.isNotEmpty) return choices;
    final normalized = (type ?? '').toLowerCase().replaceAll('-', '_');
    if (normalized == 'true_false' ||
        normalized == 'truefalse' ||
        normalized == 'boolean') {
      return const [
        AnswerChoice(id: 'true', label: 'True'),
        AnswerChoice(id: 'false', label: 'False'),
      ];
    }
    return const [];
  }

  factory AssessmentQuestionPreview.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? snapMap;
    final snapshot = json['question_snapshot'] ?? json['questionSnapshot'];
    if (snapshot is Map) {
      snapMap = snapshot.map((k, v) => MapEntry(k.toString(), v));
    }

    double? asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    int asInt(Object? raw, {int fallback = 0}) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    final contentRaw = (snapMap?['content'] ?? json['content'])?.toString();
    final content = _stripHtml(contentRaw);
    final sourceQuestionId = json['question_id']?.toString() ??
        json['questionId']?.toString() ??
        snapMap?['id']?.toString();
    final linkId = json['id']?.toString() ?? '';

    final type = (snapMap?['type'] ?? json['type'])?.toString();
    final metadata = snapMap?['metadata'];
    final rubric = snapMap?['marking_rubric'] ?? snapMap?['markingRubric'];
    int? wordLimit;
    if (metadata is Map) {
      final metaMap = metadata.map((k, v) => MapEntry(k.toString(), v));
      wordLimit = _readWordLimit(metaMap['word_limit']);
    }
    if (wordLimit == null && rubric is Map) {
      final rubricMap = rubric.map((k, v) => MapEntry(k.toString(), v));
      wordLimit = _readWordLimit(rubricMap['word_limit']);
    }

    return AssessmentQuestionPreview(
      id: linkId.isNotEmpty ? linkId : (sourceQuestionId ?? ''),
      questionId: sourceQuestionId,
      sortOrder: asInt(json['sort_order']),
      content: content,
      maxMarks: asDouble(json['max_marks'] ?? snapMap?['max_marks']),
      type: type,
      choices: _readChoices(snapMap, json),
      wordLimit: wordLimit,
      allowsImageUpload: _allowsImageUpload(type),
    );
  }

  static int? _readWordLimit(Object? raw) {
    if (raw is num && raw > 0) return raw.round();
    return int.tryParse(raw?.toString() ?? '');
  }

  static bool _allowsImageUpload(String? type) {
    final normalized = (type ?? '').toLowerCase().replaceAll('-', '_');
    if (normalized.isEmpty) return false;
    return !(
      normalized == 'mcq' ||
      normalized == 'objective' ||
      normalized == 'single_choice' ||
      normalized == 'single_select' ||
      normalized == 'true_false' ||
      normalized == 'truefalse' ||
      normalized == 'boolean' ||
      normalized == 'multiple_select' ||
      normalized.contains('mcq') ||
      normalized.contains('true_false')
    );
  }

  static String? _stripHtml(String? raw) {
    if (raw == null) return null;
    final cleaned = raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static List<AnswerChoice> _readChoices(
    Map<String, dynamic>? snapMap,
    Map<String, dynamic> question,
  ) {
    List<AnswerChoice> fromRows(Object? raw) {
      if (raw is! List) return const [];
      final out = <AnswerChoice>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final row = item.map((k, v) => MapEntry(k.toString(), v));
        final id = (row['id'] ?? row['value'])?.toString().trim() ?? '';
        final label =
            (row['label'] ?? row['text'] ?? row['name'])?.toString().trim() ??
                '';
        if (id.isEmpty || label.isEmpty) continue;
        out.add(AnswerChoice(id: id, label: label));
      }
      return out;
    }

    if (snapMap != null) {
      final rubric = snapMap['marking_rubric'] ?? snapMap['markingRubric'];
      if (rubric is Map) {
        final answer = rubric['answer'];
        if (answer is Map) {
          final fromRubric = fromRows(answer['choices']);
          if (fromRubric.isNotEmpty) return fromRubric;
        }
      }
      final metadata = snapMap['metadata'];
      if (metadata is Map) {
        final fromMeta = fromRows(metadata['choices'] ?? metadata['options']);
        if (fromMeta.isNotEmpty) return fromMeta;
      }
    }

    return fromRows(question['choices'] ?? question['options']);
  }
}

class AssessmentDetail {
  const AssessmentDetail({
    required this.id,
    required this.title,
    this.type = TestKind.other,
    this.description,
    this.instructions,
    this.totalMarks,
    this.durationMinutes,
    this.questionsCount,
    this.scheduledAt,
    this.deadlineAt,
    this.due,
    this.questions = const [],
  });

  final String id;
  final String title;
  final TestKind type;
  final String? description;
  final String? instructions;
  final double? totalMarks;
  final int? durationMinutes;
  final int? questionsCount;
  final DateTime? scheduledAt;
  final DateTime? deadlineAt;
  final DueState? due;
  final List<AssessmentQuestionPreview> questions;

  String get typeLabel {
    switch (type) {
      case TestKind.exam:
        return 'Exam';
      case TestKind.quiz:
        return 'Quiz';
      case TestKind.assignment:
        return 'Assignment';
      case TestKind.practice:
        return 'Practice';
      case TestKind.other:
        return 'Test';
    }
  }

  String get metaLine {
    final parts = <String>[
      typeLabel,
      if (durationMinutes != null && durationMinutes! > 0)
        '$durationMinutes min',
      if (totalMarks != null) '${_formatMarks(totalMarks!)} marks',
      if ((questionsCount ?? questions.length) > 0)
        '${questionsCount ?? questions.length} Qs',
    ];
    return parts.join(' · ');
  }

  factory AssessmentDetail.fromJson(
    Map<String, dynamic> json, {
    DateTime? now,
  }) {
    final deadlineRaw = json['deadline_at']?.toString() ??
        json['closes_at']?.toString();
    final scheduledRaw = json['scheduled_at']?.toString();

    double? asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    int? asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    final questionsRaw = json['questions'];
    final questions = questionsRaw is List
        ? questionsRaw
            .whereType<Map>()
            .map(
              (item) => AssessmentQuestionPreview.fromJson(
                item.map((k, v) => MapEntry(k.toString(), v)),
              ),
            )
            .where((q) => q.id.isNotEmpty)
            .toList(growable: false)
        : const <AssessmentQuestionPreview>[];

    final sorted = [...questions]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return AssessmentDetail(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim().isEmpty
          ? 'Untitled test'
          : json['title'].toString().trim(),
      type: _parseType(json['type']?.toString()),
      description: _nullableTrim(json['description']?.toString()),
      instructions: _nullableTrim(json['instructions']?.toString()),
      totalMarks: asDouble(json['total_marks']),
      durationMinutes: asInt(json['duration_minutes']),
      questionsCount: asInt(json['questions_count']) ??
          (sorted.isEmpty ? null : sorted.length),
      scheduledAt: scheduledRaw == null
          ? null
          : DateTime.tryParse(scheduledRaw)?.toLocal(),
      deadlineAt: deadlineRaw == null
          ? null
          : DateTime.tryParse(deadlineRaw)?.toLocal(),
      due: deriveDueState(deadlineRaw, now: now),
      questions: sorted,
    );
  }

  static TestKind _parseType(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'exam':
        return TestKind.exam;
      case 'quiz':
        return TestKind.quiz;
      case 'assignment':
        return TestKind.assignment;
      case 'practice':
        return TestKind.practice;
      default:
        return TestKind.other;
    }
  }

  static String? _nullableTrim(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String _formatMarks(double marks) {
    if (marks == marks.roundToDouble()) return marks.round().toString();
    return marks.toString();
  }
}

enum AttemptLifecycle { notStarted, inProgress, submitted, unknown }

class AssessmentAttemptSummary {
  const AssessmentAttemptSummary({
    required this.id,
    required this.assessmentId,
    this.attemptNumber = 1,
    this.status = AttemptLifecycle.unknown,
    this.answerSubmissionId,
    this.startedAt,
    this.submittedAt,
  });

  final String id;
  final String assessmentId;
  final int attemptNumber;
  final AttemptLifecycle status;
  final String? answerSubmissionId;
  final DateTime? startedAt;
  final DateTime? submittedAt;

  bool get isActive =>
      status == AttemptLifecycle.notStarted ||
      status == AttemptLifecycle.inProgress;

  bool get isSubmitted => status == AttemptLifecycle.submitted;

  String get statusLabel {
    switch (status) {
      case AttemptLifecycle.notStarted:
        return 'Not started';
      case AttemptLifecycle.inProgress:
        return 'In progress';
      case AttemptLifecycle.submitted:
        return 'Submitted';
      case AttemptLifecycle.unknown:
        return 'Attempt';
    }
  }

  factory AssessmentAttemptSummary.fromJson(Map<String, dynamic> json) {
    int asInt(Object? raw, {int fallback = 1}) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    return AssessmentAttemptSummary(
      id: json['id']?.toString() ?? '',
      assessmentId: json['assessment_id']?.toString() ?? '',
      attemptNumber: asInt(json['attempt_number']),
      status: _parseStatus(json['status']?.toString()),
      answerSubmissionId: json['answer_submission_id']?.toString(),
      startedAt: _parseDate(json['started_at']?.toString()),
      submittedAt: _parseDate(json['submitted_at']?.toString()),
    );
  }

  static AttemptLifecycle _parseStatus(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'not_started':
        return AttemptLifecycle.notStarted;
      case 'in_progress':
        return AttemptLifecycle.inProgress;
      case 'submitted':
        return AttemptLifecycle.submitted;
      default:
        return AttemptLifecycle.unknown;
    }
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

class SubmissionSummary {
  const SubmissionSummary({
    required this.id,
    required this.assessmentId,
    this.attemptNumber = 1,
    this.status = 'draft',
    this.assessmentAttemptId,
    this.totalScore,
    this.maxScore,
    this.percentage,
    this.submittedAt,
    this.evaluatedAt,
    this.failureReason,
    this.updatedAt,
    this.metadata = const {},
  });

  final String id;
  final String assessmentId;
  final int attemptNumber;
  final String status;
  final String? assessmentAttemptId;
  final double? totalScore;
  final double? maxScore;
  final double? percentage;
  final DateTime? submittedAt;
  final DateTime? evaluatedAt;
  final String? failureReason;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata;

  bool get isDraft => status.toLowerCase() == 'draft';

  bool get isFinalized =>
      !isDraft && status.toLowerCase() != 'pending';

  String get statusLabel => submissionStatusLabel(status);

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    int asInt(Object? raw, {int fallback = 1}) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ?? fallback;
    }

    Map<String, dynamic> metadata = const {};
    final rawMeta = json['metadata'];
    if (rawMeta is Map) {
      metadata = rawMeta.map((k, v) => MapEntry(k.toString(), v));
    }

    return SubmissionSummary(
      id: json['id']?.toString() ?? '',
      assessmentId: json['assessment_id']?.toString() ?? '',
      attemptNumber: asInt(json['attempt_number']),
      status: json['status']?.toString() ?? 'draft',
      assessmentAttemptId: json['assessment_attempt_id']?.toString(),
      totalScore: asDouble(json['total_score']),
      maxScore: asDouble(json['max_score']),
      percentage: asDouble(json['percentage']),
      submittedAt: AssessmentAttemptSummary._parseDate(
        json['submitted_at']?.toString(),
      ),
      evaluatedAt: AssessmentAttemptSummary._parseDate(
        json['evaluated_at']?.toString(),
      ),
      failureReason: _nullableTrim(json['failure_reason']?.toString()),
      updatedAt: AssessmentAttemptSummary._parseDate(
        json['updated_at']?.toString(),
      ),
      metadata: metadata,
    );
  }

  static String? _nullableTrim(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}

class FinalResultSummary {
  const FinalResultSummary({
    required this.id,
    this.attemptId,
    this.marks,
    this.rawMarks,
    this.normalisedMarks,
    this.rank,
    this.percentile,
    this.publishedAt,
  });

  final String id;
  final String? attemptId;
  final double? marks;
  final double? rawMarks;
  final double? normalisedMarks;
  final int? rank;
  final double? percentile;
  final DateTime? publishedAt;

  String get marksLabel {
    final value = normalisedMarks ?? marks ?? rawMarks;
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  factory FinalResultSummary.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? raw) {
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw?.toString() ?? '');
    }

    int? asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    return FinalResultSummary(
      id: json['id']?.toString() ?? '',
      attemptId: json['attempt_id']?.toString(),
      marks: asDouble(json['marks']),
      rawMarks: asDouble(json['raw_marks']),
      normalisedMarks: asDouble(json['normalised_marks']),
      rank: asInt(json['rank']),
      percentile: asDouble(json['percentile']),
      publishedAt: AssessmentAttemptSummary._parseDate(
        json['published_at']?.toString(),
      ),
    );
  }
}

class AssessmentDetailSnapshot {
  const AssessmentDetailSnapshot({
    required this.assessment,
    this.studentProfileId,
    this.activeAttempt,
    this.activeSubmission,
    this.finalResult,
  });

  final AssessmentDetail assessment;
  final String? studentProfileId;
  final AssessmentAttemptSummary? activeAttempt;
  final SubmissionSummary? activeSubmission;
  final FinalResultSummary? finalResult;

  bool get canStart =>
      studentProfileId != null &&
      studentProfileId!.isNotEmpty &&
      !canContinue;

  bool get canContinue =>
      activeAttempt != null &&
      activeAttempt!.isActive &&
      activeSubmission != null &&
      activeSubmission!.isDraft;

  bool get canSubmit => canContinue;
}

class AssessmentAttemptSession {
  const AssessmentAttemptSession({
    required this.attempt,
    required this.submission,
  });

  final AssessmentAttemptSummary attempt;
  final SubmissionSummary submission;
}
