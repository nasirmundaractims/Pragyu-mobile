import 'package:student_mobile/features/tests/domain/assessment_detail_models.dart';

enum CbtQuestionKind { mcq, trueFalse, shortText, essay, unsupported }

enum CbtPaletteStatus {
  notVisited,
  visited,
  answered,
  marked,
  answeredMarked,
  current,
}

enum CbtAutosaveState { idle, saving, saved, error }

class AnswerImageAttachment {
  const AnswerImageAttachment({
    required this.mediaFileId,
    required this.fileName,
    this.url,
    required this.uploadedAt,
    this.pageNumber,
  });

  final String mediaFileId;
  final String fileName;
  final String? url;
  final String uploadedAt;
  final int? pageNumber;

  Map<String, dynamic> toJson() => {
        'mediaFileId': mediaFileId,
        'fileName': fileName,
        if (url != null && url!.isNotEmpty) 'url': url,
        'uploadedAt': uploadedAt,
        if (pageNumber != null) 'pageNumber': pageNumber,
      };

  factory AnswerImageAttachment.fromJson(Map<String, dynamic> json) {
    int? page;
    final rawPage = json['pageNumber'] ?? json['page_number'];
    if (rawPage is num) {
      page = rawPage.round();
    } else {
      page = int.tryParse(rawPage?.toString() ?? '');
    }

    return AnswerImageAttachment(
      mediaFileId: json['mediaFileId']?.toString() ??
          json['media_file_id']?.toString() ??
          '',
      fileName: json['fileName']?.toString() ??
          json['file_name']?.toString() ??
          'answer.jpg',
      url: json['url']?.toString() ?? json['download_url']?.toString(),
      uploadedAt: json['uploadedAt']?.toString() ??
          json['uploaded_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      pageNumber: page,
    );
  }
}

class StudentAnswerValue {
  const StudentAnswerValue({
    this.choiceId,
    this.choiceLabel,
    this.text,
    this.images = const [],
  });

  final String? choiceId;
  final String? choiceLabel;
  final String? text;
  final List<AnswerImageAttachment> images;

  bool get isAnswered {
    if (choiceId != null && choiceId!.trim().isNotEmpty) return true;
    if (text != null && text!.trim().isNotEmpty) return true;
    if (images.isNotEmpty) return true;
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      if (choiceId != null && choiceId!.isNotEmpty) 'choiceId': choiceId,
      if (choiceLabel != null && choiceLabel!.isNotEmpty)
        'choiceLabel': choiceLabel,
      if (text != null) 'text': text,
      if (images.isNotEmpty)
        'images': images.map((image) => image.toJson()).toList(),
    };
  }

  factory StudentAnswerValue.fromJson(Map<String, dynamic> json) {
    final images = <AnswerImageAttachment>[];
    final rawImages = json['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is Map) {
          final attachment = AnswerImageAttachment.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (attachment.mediaFileId.isNotEmpty) {
            images.add(attachment);
          }
        }
      }
    }

    return StudentAnswerValue(
      choiceId: json['choiceId']?.toString() ??
          json['choice_id']?.toString(),
      choiceLabel: json['choiceLabel']?.toString() ??
          json['choice_label']?.toString(),
      text: json['text']?.toString(),
      images: images,
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

  StudentAnswerValue copyWith({
    String? text,
    List<AnswerImageAttachment>? images,
  }) {
    return StudentAnswerValue(
      choiceId: choiceId,
      choiceLabel: choiceLabel,
      text: text ?? this.text,
      images: images ?? this.images,
    );
  }
}

List<Map<String, dynamic>> buildMediaFilesMetadata(
  Map<String, StudentAnswerValue> answers,
) {
  final out = <Map<String, dynamic>>[];
  for (final answer in answers.values) {
    for (final image in answer.images) {
      out.add({
        'media_file_id': image.mediaFileId,
        'file_name': image.fileName,
        if (image.url != null && image.url!.isNotEmpty) 'url': image.url,
        'uploaded_at': image.uploadedAt,
        'page_number': image.pageNumber,
      });
    }
  }
  return out;
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
    case 'multiple_select':
      return CbtQuestionKind.mcq;
    case 'true_false':
    case 'truefalse':
    case 'boolean':
      return CbtQuestionKind.trueFalse;
    case 'essay':
    case 'subjective':
    case 'long_answer':
    case 'long_text':
    case 'descriptive':
      return CbtQuestionKind.essay;
    case 'short_answer':
    case 'short_text':
    case 'text':
    case 'numerical':
    case 'fill_in_blank':
    case 'fill_blank':
    case 'fill_in_the_blank':
      return CbtQuestionKind.shortText;
    default:
      if (choiceCount >= 2) return CbtQuestionKind.mcq;
      return CbtQuestionKind.unsupported;
  }
}

extension AssessmentQuestionCbt on AssessmentQuestionPreview {
  CbtQuestionKind get kind => parseCbtQuestionKind(
        effectiveType,
        choiceCount: choices.length,
      );
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
