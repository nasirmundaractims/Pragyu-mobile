/// Route args for S-47 Deep feedback (suggestions + AI rewrite).
class DeepFeedbackArgs {
  const DeepFeedbackArgs({
    required this.submissionId,
    required this.evaluationId,
    this.feedbackId,
    this.assessmentId,
    this.title,
    this.language,
  });

  final String submissionId;
  final String evaluationId;
  final String? feedbackId;
  final String? assessmentId;
  final String? title;
  final String? language;

  factory DeepFeedbackArgs.fromObject(Object? raw) {
    if (raw is DeepFeedbackArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return DeepFeedbackArgs(
        submissionId: map['submissionId']?.toString() ??
            map['submission_id']?.toString() ??
            '',
        evaluationId: map['evaluationId']?.toString() ??
            map['evaluation_id']?.toString() ??
            '',
        feedbackId: map['feedbackId']?.toString() ??
            map['feedback_id']?.toString(),
        assessmentId: map['assessmentId']?.toString() ??
            map['assessment_id']?.toString(),
        title: map['title']?.toString(),
        language: map['language']?.toString() ??
            map['feedback_language']?.toString(),
      );
    }
    return const DeepFeedbackArgs(submissionId: '', evaluationId: '');
  }
}

class FeedbackSuggestionItem {
  const FeedbackSuggestionItem({
    required this.id,
    this.category,
    this.title,
    this.description,
    this.priority,
    this.sortOrder = 0,
  });

  final String id;
  final String? category;
  final String? title;
  final String? description;
  final String? priority;
  final int sortOrder;

  String get headline {
    final value = title?.trim();
    if (value != null && value.isNotEmpty) return value;
    final fallback = description?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return 'Study tip';
  }

  factory FeedbackSuggestionItem.fromJson(Map<String, dynamic> json) {
    int asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    return FeedbackSuggestionItem(
      id: json['id']?.toString() ?? '',
      category: _nullableTrim(json['category']?.toString()),
      title: _nullableTrim(json['title']?.toString()),
      description: _nullableTrim(json['description']?.toString()),
      priority: _nullableTrim(json['priority']?.toString()),
      sortOrder: asInt(json['sort_order']),
    );
  }
}

class RewriteRequestSummary {
  const RewriteRequestSummary({
    required this.id,
    required this.evaluationId,
    this.status = 'requested',
    this.style,
    this.examPattern,
    this.language,
    this.wordLimit,
  });

  final String id;
  final String evaluationId;
  final String status;
  final String? style;
  final String? examPattern;
  final String? language;
  final int? wordLimit;

  bool get isProcessing {
    switch (status.toLowerCase()) {
      case 'requested':
      case 'processing':
      case 'queued':
      case 'in_progress':
      case 'running':
      case 'generating':
        return true;
      default:
        return false;
    }
  }

  bool get isCompleted => status.toLowerCase() == 'completed';

  bool get isFailed {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'error':
        return true;
      default:
        return false;
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'requested':
      case 'queued':
        return 'Queued';
      case 'processing':
      case 'in_progress':
      case 'running':
      case 'generating':
        return 'Generating…';
      case 'completed':
        return 'Ready';
      case 'failed':
      case 'error':
        return 'Failed';
      default:
        return status;
    }
  }

  factory RewriteRequestSummary.fromJson(Map<String, dynamic> json) {
    int? asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    return RewriteRequestSummary(
      id: json['id']?.toString() ?? '',
      evaluationId: json['evaluation_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'requested',
      style: _nullableTrim(json['style']?.toString()),
      examPattern: _nullableTrim(json['exam_pattern']?.toString()),
      language: _nullableTrim(json['language']?.toString()),
      wordLimit: asInt(json['word_limit']),
    );
  }
}

class RewriteResultPayload {
  const RewriteResultPayload({
    required this.id,
    required this.rewriteRequestId,
    this.rewrittenText,
    this.wordCount,
    this.disclaimer,
    this.modelAnswer,
    this.improvementItems = const [],
    this.reasoning,
    this.styleApplied = const {},
  });

  final String id;
  final String rewriteRequestId;
  final String? rewrittenText;
  final int? wordCount;
  final String? disclaimer;
  final String? modelAnswer;
  final List<String> improvementItems;
  final String? reasoning;
  final Map<String, dynamic> styleApplied;

  bool get hasRewrittenText =>
      rewrittenText != null && rewrittenText!.trim().isNotEmpty;

  bool get hasModelAnswer =>
      modelAnswer != null && modelAnswer!.trim().isNotEmpty;

  factory RewriteResultPayload.fromJson(Map<String, dynamic> json) {
    final style = _asMap(json['style_applied']);
    final rewritten = _nullableTrim(
      json['rewritten_text']?.toString() ??
          json['improved_answer']?.toString() ??
          json['text']?.toString() ??
          json['content']?.toString() ??
          json['answer']?.toString(),
    );

    final model = _nullableTrim(
      json['model_answer']?.toString() ??
          style['model_answer']?.toString(),
    );

    final improvements = <String>[];
    final rawItems = json['improvement_items'] ?? style['improvement_items'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is String) {
          final text = item.trim();
          if (text.isNotEmpty) improvements.add(text);
        } else if (item is Map) {
          final reason = item['reason']?.toString().trim();
          final improved = item['improved']?.toString().trim();
          final combined = [
            if (reason != null && reason.isNotEmpty) reason,
            if (improved != null && improved.isNotEmpty) improved,
          ].join(': ');
          if (combined.isNotEmpty) improvements.add(combined);
        }
      }
    }

    int? asInt(Object? raw) {
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '');
    }

    return RewriteResultPayload(
      id: json['id']?.toString() ?? '',
      rewriteRequestId: json['rewrite_request_id']?.toString() ?? '',
      rewrittenText: rewritten,
      wordCount: asInt(json['word_count']),
      disclaimer: _nullableTrim(json['disclaimer']?.toString()),
      modelAnswer: model,
      improvementItems: improvements,
      reasoning: _nullableTrim(
        json['reasoning']?.toString() ?? style['reasoning']?.toString(),
      ),
      styleApplied: style,
    );
  }
}

class RewriteOptions {
  const RewriteOptions({
    this.style = 'academic',
    this.examPattern = 'essay',
    this.wordLimit = 200,
    this.language = 'en',
    this.studentProfileId,
  });

  final String style;
  final String examPattern;
  final int wordLimit;
  final String language;
  final String? studentProfileId;

  Map<String, dynamic> toJson() => {
        'style': style,
        'exam_pattern': examPattern,
        'word_limit': wordLimit,
        'language': language,
        if (studentProfileId != null && studentProfileId!.isNotEmpty)
          'student_profile_id': studentProfileId,
      };
}

class DeepFeedbackSnapshot {
  const DeepFeedbackSnapshot({
    this.suggestions = const [],
    this.latestRewrite,
    this.rewriteResult,
    this.originalAnswerText,
  });

  final List<FeedbackSuggestionItem> suggestions;
  final RewriteRequestSummary? latestRewrite;
  final RewriteResultPayload? rewriteResult;
  final String? originalAnswerText;
}

/// Pull readable answer text from submission metadata.answers.
String? extractOriginalAnswerText(Map<String, dynamic> metadata) {
  final answers = metadata['answers'];
  if (answers is! Map) return null;

  final chunks = <String>[];
  answers.forEach((_, value) {
    if (value is String) {
      final text = value.trim();
      if (text.isNotEmpty) chunks.add(text);
      return;
    }
    if (value is Map) {
      final text = (value['text'] ?? value['answer'] ?? value['content'])
          ?.toString()
          .trim();
      if (text != null && text.isNotEmpty) {
        chunks.add(text);
        return;
      }
      final choice = value['choice_label'] ?? value['selected_label'];
      if (choice != null) {
        final label = choice.toString().trim();
        if (label.isNotEmpty) chunks.add(label);
      }
    }
  });

  if (chunks.isEmpty) return null;
  return chunks.join('\n\n');
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return const {};
}

String? _nullableTrim(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}
