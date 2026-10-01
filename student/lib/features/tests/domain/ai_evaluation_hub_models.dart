import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';
import 'package:student_mobile/features/tests/domain/cbt_player_models.dart';
import 'package:student_mobile/features/tests/domain/submission_status_models.dart';

enum AiAnswerKind { shortAnswer, longAnswer }

enum AiEvalQuestionStatus {
  notStarted,
  draft,
  evaluating,
  evaluated,
  failed,
}

/// One AI-evaluable question shown on the AI Eval hub.
class AiEvalQuestionItem {
  const AiEvalQuestionItem({
    required this.assessmentId,
    required this.assessmentTitle,
    required this.question,
    required this.questionIndex,
    required this.questionTotal,
    required this.kind,
    required this.status,
    this.subjectLabel = 'General',
    this.examCategory = 'AI Evaluation',
    this.submission,
    this.scoreAwarded,
    this.scoreMax,
  });

  final String assessmentId;
  final String assessmentTitle;
  final AssessmentQuestionPreview question;
  final int questionIndex;
  final int questionTotal;
  final AiAnswerKind kind;
  final AiEvalQuestionStatus status;
  final String subjectLabel;
  final String examCategory;
  final SubmissionSummary? submission;
  final double? scoreAwarded;
  final double? scoreMax;

  String get questionText {
    final text = (question.content ?? '').trim();
    if (text.isNotEmpty) return text;
    return 'Question ${questionIndex + 1}';
  }

  String get kindLabel =>
      kind == AiAnswerKind.shortAnswer ? 'Short answer' : 'Long answer';

  /// One-line hint so Short vs Long is clear without a tutorial.
  String get kindHint => kind == AiAnswerKind.shortAnswer
      ? 'Concise written response'
      : 'Essay / descriptive response';

  String get primaryActionLabel {
    switch (status) {
      case AiEvalQuestionStatus.notStarted:
        return 'Upload answer';
      case AiEvalQuestionStatus.draft:
        return 'Continue upload';
      case AiEvalQuestionStatus.evaluating:
        return 'Check status';
      case AiEvalQuestionStatus.evaluated:
        return 'View score';
      case AiEvalQuestionStatus.failed:
        return 'Upload again';
    }
  }

  String get statusLabel {
    switch (status) {
      case AiEvalQuestionStatus.notStarted:
        return 'Ready to upload';
      case AiEvalQuestionStatus.draft:
        return 'Draft — continue upload';
      case AiEvalQuestionStatus.evaluating:
        return 'AI evaluating';
      case AiEvalQuestionStatus.evaluated:
        return 'Score ready';
      case AiEvalQuestionStatus.failed:
        return 'Needs attention — try again';
    }
  }

  String get scoreLabel {
    if (scoreAwarded == null && scoreMax == null) return '';
    final awarded = scoreAwarded;
    final max = scoreMax ?? question.maxMarks;
    if (awarded == null) return max == null ? '' : '/ ${_fmt(max)}';
    if (max == null) return _fmt(awarded);
    return '${_fmt(awarded)} / ${_fmt(max)}';
  }

  bool get canReattempt =>
      status == AiEvalQuestionStatus.evaluated ||
      status == AiEvalQuestionStatus.failed;

  static AiAnswerKind kindFor(AssessmentQuestionPreview question) {
    final type = (question.effectiveType ?? question.type ?? '')
        .toLowerCase()
        .replaceAll('-', '_');
    if (type.contains('short')) return AiAnswerKind.shortAnswer;
    if (type.contains('long') ||
        type.contains('essay') ||
        type.contains('descriptive') ||
        type.contains('subjective')) {
      return AiAnswerKind.longAnswer;
    }
    final limit = question.wordLimit;
    if (limit != null && limit > 0 && limit <= 120) {
      return AiAnswerKind.shortAnswer;
    }
    return AiAnswerKind.longAnswer;
  }

  static String _fmt(double value) {
    if (value == value.roundToDouble()) return '${value.round()}';
    return value.toStringAsFixed(1);
  }
}

AiEvalQuestionStatus resolveAiEvalStatus(SubmissionSummary? submission) {
  if (submission == null) return AiEvalQuestionStatus.notStarted;
  if (submission.isDraft) return AiEvalQuestionStatus.draft;
  if (SubmissionPipeline.isReady(submission.status)) {
    return AiEvalQuestionStatus.evaluated;
  }
  if (SubmissionPipeline.isFailed(submission.status)) {
    return AiEvalQuestionStatus.failed;
  }
  if (SubmissionPipeline.isPending(submission.status)) {
    return AiEvalQuestionStatus.evaluating;
  }
  return AiEvalQuestionStatus.notStarted;
}

bool isAiEvaluableQuestion(AssessmentQuestionPreview question) {
  final kind = parseCbtQuestionKind(
    question.effectiveType ?? question.type,
    choiceCount: question.effectiveChoices.length,
  );
  return kind == CbtQuestionKind.essay ||
      kind == CbtQuestionKind.shortText ||
      question.allowsImageUpload;
}
