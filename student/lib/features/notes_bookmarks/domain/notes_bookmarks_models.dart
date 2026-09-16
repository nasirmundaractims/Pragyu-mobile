/// S-64 Notes, bookmarks, and AI feedback library models.
library;

enum NotesHubSegment { notes, bookmarks, feedback }

class StudyNote {
  const StudyNote({
    required this.id,
    required this.body,
    this.title,
    this.lessonId,
    this.resourceId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String body;
  final String? title;
  final String? lessonId;
  final String? resourceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayTitle {
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    final firstLine = body.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled note';
    return firstLine.length > 48 ? '${firstLine.substring(0, 48)}…' : firstLine;
  }

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      id: json['id']?.toString() ?? '',
      body: (json['body'] ?? '').toString(),
      title: _nullable(json['title']),
      lessonId: _nullable(json['lesson_id']),
      resourceId: _nullable(json['resource_id']),
      createdAt: _parseDate(json['created_at']?.toString()),
      updatedAt: _parseDate(json['updated_at']?.toString()),
    );
  }
}

class ContentBookmark {
  const ContentBookmark({
    required this.id,
    required this.bookmarkableType,
    required this.bookmarkableId,
    this.title,
    this.createdAt,
  });

  final String id;
  final String bookmarkableType;
  final String bookmarkableId;
  final String? title;
  final DateTime? createdAt;

  String get displayTitle {
    final t = title?.trim() ?? '';
    if (t.isNotEmpty) return t;
    return '${typeLabel} · ${bookmarkableId.length > 8 ? bookmarkableId.substring(0, 8) : bookmarkableId}';
  }

  String get typeLabel {
    switch (bookmarkableType.toLowerCase()) {
      case 'lesson':
        return 'Lesson';
      case 'pdf':
        return 'PDF';
      case 'video':
        return 'Video';
      case 'resource':
        return 'Resource';
      default:
        return bookmarkableType;
    }
  }

  bool get isLesson => bookmarkableType.toLowerCase() == 'lesson';

  factory ContentBookmark.fromJson(Map<String, dynamic> json) {
    return ContentBookmark(
      id: json['id']?.toString() ?? '',
      bookmarkableType:
          (json['bookmarkable_type'] ?? json['type'] ?? 'resource').toString(),
      bookmarkableId:
          (json['bookmarkable_id'] ?? json['target_id'] ?? '').toString(),
      title: _nullable(json['title']),
      createdAt: _parseDate(json['created_at']?.toString()),
    );
  }
}

class FeedbackReportItem {
  const FeedbackReportItem({
    required this.submissionId,
    required this.assessmentId,
    required this.title,
    this.attemptNumber = 1,
    this.totalScore,
    this.maxScore,
    this.percentage,
    this.evaluatedAt,
  });

  final String submissionId;
  final String assessmentId;
  final String title;
  final int attemptNumber;
  final double? totalScore;
  final double? maxScore;
  final double? percentage;
  final DateTime? evaluatedAt;

  String get scoreLabel {
    if (totalScore != null && maxScore != null) {
      return '${_fmt(totalScore!)} / ${_fmt(maxScore!)}';
    }
    if (percentage != null) return '${percentage!.round()}%';
    return 'Scored';
  }

  String get percentLabel =>
      percentage == null ? '—' : '${percentage!.round()}%';

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  factory FeedbackReportItem.fromSubmissionJson(
    Map<String, dynamic> json, {
    Map<String, String> titles = const {},
  }) {
    final assessmentId = (json['assessment_id'] ?? '').toString();
    final title = titles[assessmentId] ??
        _nullable(json['assessment_title']) ??
        (assessmentId.isEmpty
            ? 'Assessment'
            : 'Assessment ${assessmentId.length > 8 ? assessmentId.substring(0, 8) : assessmentId}…');
    return FeedbackReportItem(
      submissionId: json['id']?.toString() ?? '',
      assessmentId: assessmentId,
      title: title,
      attemptNumber: _int(json['attempt_number']) ?? 1,
      totalScore: _double(json['total_score']),
      maxScore: _double(json['max_score']),
      percentage: _double(json['percentage']),
      evaluatedAt: _parseDate(
        (json['evaluated_at'] ?? json['submitted_at'])?.toString(),
      ),
    );
  }
}

class NotesBookmarksSnapshot {
  const NotesBookmarksSnapshot({
    this.notes = const [],
    this.bookmarks = const [],
    this.feedback = const [],
  });

  final List<StudyNote> notes;
  final List<ContentBookmark> bookmarks;
  final List<FeedbackReportItem> feedback;

  double? get latestFeedbackPercent =>
      feedback.isEmpty ? null : feedback.first.percentage;

  NotesBookmarksSnapshot copyWith({
    List<StudyNote>? notes,
    List<ContentBookmark>? bookmarks,
    List<FeedbackReportItem>? feedback,
  }) {
    return NotesBookmarksSnapshot(
      notes: notes ?? this.notes,
      bookmarks: bookmarks ?? this.bookmarks,
      feedback: feedback ?? this.feedback,
    );
  }
}

String? _nullable(Object? raw) {
  final text = raw?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _int(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw?.toString() ?? '');
}

double? _double(Object? raw) {
  if (raw is double) return raw;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '');
}

DateTime? _parseDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
