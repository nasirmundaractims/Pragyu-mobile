import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

export 'package:student_mobile/features/tests/domain/submission_status_models.dart'
    show ResultFeedbackArgs;

/// Snapshot for S-46 Result / feedback.
class ResultFeedbackSnapshot {
  const ResultFeedbackSnapshot({
    required this.submission,
    this.evaluation,
    this.scores = const [],
    this.feedback,
  });

  final SubmissionSummary submission;
  final EvaluationSummary? evaluation;
  final List<EvaluationScoreItem> scores;
  final EvaluationFeedbackReport? feedback;

  double? get totalScore =>
      evaluation?.totalScore ?? submission.totalScore;

  double? get maxScore => evaluation?.maxScore ?? submission.maxScore;

  double? get percentage =>
      evaluation?.percentage ?? submission.percentage;

  String get scoreLabel => formatScorePair(totalScore, maxScore);

  String? get percentageLabel {
    final value = percentage;
    if (value == null) return null;
    if (value == value.roundToDouble()) return '${value.round()}%';
    return '${value.toStringAsFixed(1)}%';
  }
}

class EvaluationSummary {
  const EvaluationSummary({
    required this.id,
    required this.submissionId,
    this.assessmentId,
    this.status = 'completed',
    this.totalScore,
    this.maxScore,
    this.percentage,
    this.grade,
    this.feedbackSummary,
    this.completedAt,
  });

  final String id;
  final String submissionId;
  final String? assessmentId;
  final String status;
  final double? totalScore;
  final double? maxScore;
  final double? percentage;
  final String? grade;
  final String? feedbackSummary;
  final DateTime? completedAt;

  factory EvaluationSummary.fromJson(Map<String, dynamic> json) {
    return EvaluationSummary(
      id: json['id']?.toString() ?? '',
      submissionId: json['answer_submission_id']?.toString() ??
          json['submission_id']?.toString() ??
          '',
      assessmentId: json['assessment_id']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      totalScore: _asDouble(json['total_score']),
      maxScore: _asDouble(json['max_score']),
      percentage: _asDouble(json['percentage']),
      grade: _nullableTrim(json['grade']?.toString()),
      feedbackSummary: _nullableTrim(json['feedback_summary']?.toString()),
      completedAt: _parseDate(json['completed_at']?.toString()),
    );
  }
}

class EvaluationScoreItem {
  const EvaluationScoreItem({
    required this.id,
    this.questionId,
    this.assessmentQuestionId,
    this.scoreAwarded,
    this.effectiveScore,
    this.maxScore,
    this.feedback,
    this.rubricBreakdown = const {},
    this.isOverridden = false,
  });

  final String id;
  final String? questionId;
  final String? assessmentQuestionId;
  final double? scoreAwarded;
  final double? effectiveScore;
  final double? maxScore;
  final String? feedback;
  final Map<String, dynamic> rubricBreakdown;
  final bool isOverridden;

  double? get displayScore => effectiveScore ?? scoreAwarded;

  String get scoreLabel => formatScorePair(displayScore, maxScore);

  factory EvaluationScoreItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> rubric = const {};
    final raw = json['rubric_breakdown'];
    if (raw is Map) {
      rubric = raw.map((k, v) => MapEntry(k.toString(), v));
    }

    return EvaluationScoreItem(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString(),
      assessmentQuestionId: json['assessment_question_id']?.toString(),
      scoreAwarded: _asDouble(json['score_awarded']),
      effectiveScore: _asDouble(json['effective_score']),
      maxScore: _asDouble(json['max_score']),
      feedback: _nullableTrim(json['feedback']?.toString()),
      rubricBreakdown: rubric,
      isOverridden: json['is_overridden'] == true,
    );
  }
}

class EvaluationFeedbackReport {
  const EvaluationFeedbackReport({
    required this.id,
    required this.evaluationId,
    this.status = 'completed',
    this.summary,
    this.strengths = const [],
    this.weaknesses = const [],
    this.missingKeywords = const [],
    this.missingConcepts = const [],
    this.actionItems = const [],
    this.writingTips = const [],
  });

  final String id;
  final String evaluationId;
  final String status;
  final String? summary;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> missingKeywords;
  final List<String> missingConcepts;
  final List<String> actionItems;
  final List<String> writingTips;

  List<String> get improvementAreas {
    final merged = <String>[
      ...missingKeywords,
      ...missingConcepts,
    ];
    final seen = <String>{};
    return merged.where((item) => seen.add(item.toLowerCase())).toList();
  }

  List<String> get tips {
    final merged = <String>[
      ...writingTips,
      ...actionItems,
    ];
    final seen = <String>{};
    return merged.where((item) => seen.add(item.toLowerCase())).toList();
  }

  bool get hasContent =>
      (summary != null && summary!.isNotEmpty) ||
      strengths.isNotEmpty ||
      weaknesses.isNotEmpty ||
      improvementAreas.isNotEmpty ||
      tips.isNotEmpty;

  factory EvaluationFeedbackReport.fromJson(Map<String, dynamic> json) {
    return EvaluationFeedbackReport(
      id: json['id']?.toString() ?? '',
      evaluationId: json['evaluation_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'completed',
      summary: _nullableTrim(
        json['summary']?.toString() ??
            json['overall_feedback']?.toString() ??
            json['feedback']?.toString(),
      ),
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      missingKeywords: _stringList(json['missing_keywords']),
      missingConcepts: _stringList(json['missing_concepts']),
      actionItems: _stringList(json['action_items']),
      writingTips: _stringList(json['writing_tips']),
    );
  }
}

String formatScorePair(double? awarded, double? max) {
  if (awarded == null && max == null) return '—';
  final left = awarded == null ? '—' : _trimNumber(awarded);
  if (max == null) return left;
  return '$left / ${_trimNumber(max)}';
}

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}

double? _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String? _nullableTrim(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
