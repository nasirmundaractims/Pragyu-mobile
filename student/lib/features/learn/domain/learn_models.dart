/// S-20 My learning — enrolled course row from account/courses.
class LearningCourse {
  const LearningCourse({
    required this.courseId,
    required this.title,
    this.enrollmentId,
    this.programId,
    this.programName,
    this.batchName,
    this.status,
    this.isActive = false,
    this.progressPercent,
  });

  final String courseId;
  final String title;
  final String? enrollmentId;
  final String? programId;
  final String? programName;
  final String? batchName;
  final String? status;
  final bool isActive;
  final int? progressPercent;

  String get subtitle {
    final parts = <String>[
      if (programName != null &&
          programName!.isNotEmpty &&
          programName != title)
        programName!,
      if (batchName != null && batchName!.isNotEmpty) batchName!,
    ];
    return parts.join(' · ');
  }

  String get statusLabel {
    if (isActive) return 'Active';
    final raw = status?.trim();
    if (raw == null || raw.isEmpty) return 'Inactive';
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class MyLearningSnapshot {
  const MyLearningSnapshot({this.courses = const []});

  final List<LearningCourse> courses;

  bool get isEmpty => courses.isEmpty;
}

/// Route args for S-21 Course detail.
class CourseDetailArgs {
  const CourseDetailArgs({
    required this.courseId,
    this.title,
    this.programName,
    this.batchName,
  });

  final String courseId;
  final String? title;
  final String? programName;
  final String? batchName;

  factory CourseDetailArgs.fromObject(Object? raw) {
    if (raw is CourseDetailArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return CourseDetailArgs(
        courseId: map['courseId']?.toString() ??
            map['course_id']?.toString() ??
            '',
        title: map['title']?.toString() ?? map['course_name']?.toString(),
        programName: map['programName']?.toString() ??
            map['program_name']?.toString(),
        batchName:
            map['batchName']?.toString() ?? map['batch_name']?.toString(),
      );
    }
    if (raw is String) {
      return CourseDetailArgs(courseId: raw);
    }
    return const CourseDetailArgs(courseId: '');
  }
}

class CourseProgressSummary {
  const CourseProgressSummary({
    this.completionPercent = 0,
    this.totalLessons = 0,
    this.completedLessons = 0,
    this.courseCompleted = false,
  });

  final int completionPercent;
  final int totalLessons;
  final int completedLessons;
  final bool courseCompleted;

  int get remainingLessons {
    final left = totalLessons - completedLessons;
    return left < 0 ? 0 : left;
  }
}

class ContinueLearningCursor {
  const ContinueLearningCursor({
    required this.hasCursor,
    this.courseId,
    this.lessonId,
    this.lessonTitle,
  });

  final bool hasCursor;
  final String? courseId;
  final String? lessonId;
  final String? lessonTitle;
}

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.title,
    this.topicPath,
    this.status,
    this.progressPercent,
    this.estimatedMinutes,
  });

  final String id;
  final String title;
  final String? topicPath;
  final String? status;
  final int? progressPercent;
  final int? estimatedMinutes;

  bool get isCompleted =>
      status == 'completed' || (progressPercent ?? 0) >= 100;

  String get statusLabel {
    if (isCompleted) return 'Done';
    if (status == 'in_progress' || (progressPercent ?? 0) > 0) {
      return 'In progress';
    }
    return 'Not started';
  }
}

class CourseModule {
  const CourseModule({
    required this.id,
    required this.title,
    this.lessons = const [],
  });

  final String id;
  final String title;
  final List<CourseLesson> lessons;

  int get completedCount => lessons.where((l) => l.isCompleted).length;
}

class CourseDetailSnapshot {
  const CourseDetailSnapshot({
    required this.courseId,
    this.title,
    this.programName,
    this.batchName,
    this.progress = const CourseProgressSummary(),
    this.continueCursor = const ContinueLearningCursor(hasCursor: false),
    this.modules = const [],
  });

  final String courseId;
  final String? title;
  final String? programName;
  final String? batchName;
  final CourseProgressSummary progress;
  final ContinueLearningCursor continueCursor;
  final List<CourseModule> modules;

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty) ? title!.trim() : 'Course';

  String get subtitle {
    final parts = <String>[
      if (programName != null &&
          programName!.isNotEmpty &&
          programName != displayTitle)
        programName!,
      if (batchName != null && batchName!.isNotEmpty) batchName!,
    ];
    return parts.join(' · ');
  }

  /// Continue target for this course (cursor match or first incomplete lesson).
  CourseLesson? get continueLesson {
    final cursor = continueCursor;
    if (cursor.hasCursor &&
        cursor.lessonId != null &&
        cursor.lessonId!.isNotEmpty &&
        (cursor.courseId == null ||
            cursor.courseId!.isEmpty ||
            cursor.courseId == courseId)) {
      for (final module in modules) {
        for (final lesson in module.lessons) {
          if (lesson.id == cursor.lessonId) return lesson;
        }
      }
      return CourseLesson(
        id: cursor.lessonId!,
        title: cursor.lessonTitle?.isNotEmpty == true
            ? cursor.lessonTitle!
            : 'Continue learning',
      );
    }

    for (final module in modules) {
      for (final lesson in module.lessons) {
        if (!lesson.isCompleted) return lesson;
      }
    }
    if (modules.isNotEmpty && modules.first.lessons.isNotEmpty) {
      return modules.first.lessons.first;
    }
    return null;
  }

  bool get hasModules => modules.isNotEmpty;
}

/// Route args for S-22 Lesson / content player.
class LessonDetailArgs {
  const LessonDetailArgs({
    required this.lessonId,
    this.courseId,
    this.title,
  });

  final String lessonId;
  final String? courseId;
  final String? title;

  factory LessonDetailArgs.fromObject(Object? raw) {
    if (raw is LessonDetailArgs) return raw;
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      return LessonDetailArgs(
        lessonId: map['lessonId']?.toString() ??
            map['lesson_id']?.toString() ??
            '',
        courseId:
            map['courseId']?.toString() ?? map['course_id']?.toString(),
        title: map['title']?.toString(),
      );
    }
    if (raw is String) {
      return LessonDetailArgs(lessonId: raw);
    }
    return const LessonDetailArgs(lessonId: '');
  }
}

class LessonProgressState {
  const LessonProgressState({
    this.status = 'not_started',
    this.progressPercent = 0,
    this.completedAt,
  });

  final String status;
  final int progressPercent;
  final String? completedAt;

  bool get isCompleted =>
      status == 'completed' || progressPercent >= 100;

  String get statusLabel {
    if (isCompleted) return 'Completed';
    if (status == 'in_progress' || progressPercent > 0) return 'In progress';
    return 'Not started';
  }

  LessonProgressState copyWith({
    String? status,
    int? progressPercent,
    String? completedAt,
  }) {
    return LessonProgressState(
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class LessonResource {
  const LessonResource({
    required this.id,
    required this.title,
    required this.resourceType,
    this.externalUrl,
    this.contentText,
    this.durationSeconds,
    this.isDownloadable = false,
  });

  final String id;
  final String title;
  final String resourceType;
  final String? externalUrl;
  final String? contentText;
  final int? durationSeconds;
  final bool isDownloadable;

  String get typeLabel {
    final raw = resourceType.trim();
    if (raw.isEmpty) return 'Resource';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  bool get isStreamableMedia {
    final type = resourceType.toLowerCase();
    final url = (externalUrl ?? '').toLowerCase();
    return type.contains('video') ||
        type.contains('audio') ||
        type.contains('recording') ||
        url.contains('.mp4') ||
        url.contains('.m3u8') ||
        url.contains('.mp3') ||
        url.contains('.webm');
  }

  bool get hasPlayableUrl {
    final url = externalUrl?.trim();
    return url != null && url.isNotEmpty;
  }
}

class LessonDetailSnapshot {
  const LessonDetailSnapshot({
    required this.lessonId,
    required this.title,
    this.summary,
    this.bodyHtml,
    this.bodyText,
    this.estimatedMinutes,
    this.assessmentId,
    this.hierarchyLabel,
    this.courseId,
    this.resources = const [],
    this.progress = const LessonProgressState(),
  });

  final String lessonId;
  final String title;
  final String? summary;
  final String? bodyHtml;
  final String? bodyText;
  final int? estimatedMinutes;
  final String? assessmentId;
  final String? hierarchyLabel;
  final String? courseId;
  final List<LessonResource> resources;
  final LessonProgressState progress;

  String get contentText {
    if (bodyText != null && bodyText!.trim().isNotEmpty) {
      return bodyText!.trim();
    }
    if (bodyHtml != null && bodyHtml!.trim().isNotEmpty) {
      return stripHtml(bodyHtml!);
    }
    if (summary != null && summary!.trim().isNotEmpty) {
      return summary!.trim();
    }
    return '';
  }

  LessonDetailSnapshot copyWith({
    LessonProgressState? progress,
  }) {
    return LessonDetailSnapshot(
      lessonId: lessonId,
      title: title,
      summary: summary,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
      estimatedMinutes: estimatedMinutes,
      assessmentId: assessmentId,
      hierarchyLabel: hierarchyLabel,
      courseId: courseId,
      resources: resources,
      progress: progress ?? this.progress,
    );
  }
}

/// Minimal HTML → plain text for Phase A lesson body.
String stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
