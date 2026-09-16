import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

enum CbtQuestionKind { mcq, trueFalse, shortText, unsupported }

enum CbtPaletteStatus {
  notVisited,
  visited,
  answered,
  marked,
  answeredMarked,
  current,
}

enum CbtAutosaveState { idle, saving, saved, error }

class StudentAnswerValue {
  const StudentAnswerValue({
    this.choiceId,
    this.choiceLabel,
    this.text,
  });

  final String? choiceId;
  final String? choiceLabel;
  final String? text;

  bool get isAnswered {
    if (choiceId != null && choiceId!.trim().isNotEmpty) return true;
    if (text != null && text!.trim().isNotEmpty) return true;
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      if (choiceId != null && choiceId!.isNotEmpty) 'choiceId': choiceId,
      if (choiceLabel != null && choiceLabel!.isNotEmpty)
        'choiceLabel': choiceLabel,
      if (text != null) 'text': text,
    };
  }

  factory StudentAnswerValue.fromJson(Map<String, dynamic> json) {
    return StudentAnswerValue(
      choiceId: json['choiceId']?.toString() ??
          json['choice_id']?.toString(),
      choiceLabel: json['choiceLabel']?.toString() ??
          json['choice_label']?.toString(),
      text: json['text']?.toString(),
    );
  }

  factory StudentAnswerValue.choice({
    required String id,
    required String label,
  }) {
    return StudentAnswerValue(
      choiceId: id,
      choiceLabel: label,
      text: label,
    );
  }

  factory StudentAnswerValue.written(String text) {
    return StudentAnswerValue(text: text);
  }
}

class CbtPlayerState {
  const CbtPlayerState({
    this.currentQuestionId,
    this.visited = const [],
    this.markedForReview = const [],
    this.instructionsAcked = true,
    this.startedAt,
    this.deadlineAt,
  });

  final String? currentQuestionId;
  final List<String> visited;
  final List<String> markedForReview;
  final bool instructionsAcked;
  final DateTime? startedAt;
  final DateTime? deadlineAt;

  CbtPlayerState copyWith({
    String? currentQuestionId,
    List<String>? visited,
    List<String>? markedForReview,
    bool? instructionsAcked,
    DateTime? startedAt,
    DateTime? deadlineAt,
    bool clearDeadline = false,
  }) {
    return CbtPlayerState(
      currentQuestionId: currentQuestionId ?? this.currentQuestionId,
      visited: visited ?? this.visited,
      markedForReview: markedForReview ?? this.markedForReview,
      instructionsAcked: instructionsAcked ?? this.instructionsAcked,
      startedAt: startedAt ?? this.startedAt,
      deadlineAt: clearDeadline ? null : (deadlineAt ?? this.deadlineAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_question_id': currentQuestionId,
      'visited': visited,
      'marked_for_review': markedForReview,
      'instructions_acked': instructionsAcked,
      'started_at': startedAt?.toUtc().toIso8601String(),
      'deadline_at': deadlineAt?.toUtc().toIso8601String(),
      'security_events': const <Map<String, dynamic>>[],
    };
  }

  factory CbtPlayerState.fromJson(Object? raw) {
    if (raw is! Map) return const CbtPlayerState();
    final json = raw.map((k, v) => MapEntry(k.toString(), v));
    DateTime? parseDate(Object? value) {
      final text = value?.toString();
      if (text == null || text.isEmpty) return null;
      return DateTime.tryParse(text)?.toLocal();
    }

    return CbtPlayerState(
      currentQuestionId: json['current_question_id']?.toString(),
      visited: json['visited'] is List
          ? (json['visited'] as List).map((e) => e.toString()).toList()
          : const [],
      markedForReview: json['marked_for_review'] is List
          ? (json['marked_for_review'] as List)
              .map((e) => e.toString())
              .toList()
          : const [],
      instructionsAcked: json['instructions_acked'] == true,
      startedAt: parseDate(json['started_at']),
      deadlineAt: parseDate(json['deadline_at']),
    );
  }
}

class AttemptPlayerSnapshot {
  const AttemptPlayerSnapshot({
    required this.assessment,
    required this.questions,
    required this.answers,
    required this.player,
    required this.submissionId,
    required this.attemptId,
  });

  final AssessmentDetail assessment;
  final List<AssessmentQuestionPreview> questions;
  final Map<String, StudentAnswerValue> answers;
  final CbtPlayerState player;
  final String submissionId;
  final String attemptId;

  int get answeredCount =>
      answers.values.where((value) => value.isAnswered).length;

  int get markedCount => player.markedForReview.length;

  int get unansweredCount {
    final total = questions.length;
    return total < answeredCount ? 0 : total - answeredCount;
  }
}

CbtQuestionKind parseCbtQuestionKind(String? raw, {int choiceCount = 0}) {
  switch ((raw ?? '').toLowerCase().trim().replaceAll('-', '_')) {
    case 'mcq':
    case 'objective':
    case 'single_choice':
    case 'single_select':
      return CbtQuestionKind.mcq;
    case 'true_false':
    case 'truefalse':
    case 'boolean':
      return CbtQuestionKind.trueFalse;
    case 'short_answer':
    case 'short_text':
    case 'text':
    case 'subjective':
    case 'essay':
      return CbtQuestionKind.shortText;
    default:
      if (choiceCount >= 2) return CbtQuestionKind.mcq;
      return CbtQuestionKind.unsupported;
  }
}

extension AssessmentQuestionCbt on AssessmentQuestionPreview {
  CbtQuestionKind get kind =>
      parseCbtQuestionKind(type, choiceCount: choices.length);
}

CbtPaletteStatus paletteStatusFor({
  required String questionId,
  required String? currentId,
  required Set<String> visited,
  required Set<String> marked,
  required bool answered,
}) {
  if (questionId == currentId) return CbtPaletteStatus.current;
  final isMarked = marked.contains(questionId);
  if (answered && isMarked) return CbtPaletteStatus.answeredMarked;
  if (isMarked) return CbtPaletteStatus.marked;
  if (answered) return CbtPaletteStatus.answered;
  if (visited.contains(questionId)) return CbtPaletteStatus.visited;
  return CbtPaletteStatus.notVisited;
}

String formatRemaining(Duration remaining) {
  final safe = remaining.isNegative ? Duration.zero : remaining;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
