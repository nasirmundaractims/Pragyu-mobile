import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';

abstract class LearnGateway {
  Future<MyLearningSnapshot> loadMyLearning();
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args);
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args);
  Future<LessonProgressState> completeLesson(String lessonId);
}

class LearnRepository implements LearnGateway {
  LearnRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<MyLearningSnapshot> loadMyLearning() async {
    final session = await _requireSession();

    final envelope = await _api.get(
      '/students/me/account/courses',
      query: const {'status': 'all'},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) {
      return const MyLearningSnapshot();
    }

    final courses = data
        .whereType<Map>()
        .map(_parseCourse)
        .whereType<LearningCourse>()
        .toList(growable: false);

    final sorted = [...courses]..sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    return MyLearningSnapshot(courses: sorted);
  }

  @override
  Future<CourseDetailSnapshot> loadCourseDetail(CourseDetailArgs args) async {
    final courseId = args.courseId.trim();
    if (courseId.isEmpty) {
      throw ArgumentError('courseId is required');
    }

    final session = await _requireSession();

    final structureFuture = _api.get(
      '/students/me/learning/courses/$courseId/structure',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final progressFuture = _api.get(
      '/students/me/learning/progress',
      query: {'course_id': courseId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final continueFuture = _api.get(
      '/students/me/learning/continue',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final structureEnvelope = await structureFuture;
    CourseProgressSummary progress = const CourseProgressSummary();
    ContinueLearningCursor continueCursor =
        const ContinueLearningCursor(hasCursor: false);

    try {
      final progressEnvelope = await progressFuture;
      progress = _parseProgress(progressEnvelope['data']);
    } catch (_) {
      // Structure is required; progress is best-effort.
    }

    try {
      final continueEnvelope = await continueFuture;
      continueCursor = _parseContinue(continueEnvelope['data']);
    } catch (_) {
      // Optional.
    }

    final structureData = structureEnvelope['data'];
    final structureMap = structureData is Map
        ? structureData.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final modules = _parseModules(structureMap['modules']);
    final titleFromApi = structureMap['course_name']?.toString() ??
        structureMap['title']?.toString();

    return CourseDetailSnapshot(
      courseId: courseId,
      title: (args.title != null && args.title!.trim().isNotEmpty)
          ? args.title
          : titleFromApi,
      programName: args.programName,
      batchName: args.batchName,
      progress: progress,
      continueCursor: continueCursor,
      modules: modules,
    );
  }

  @override
  Future<LessonDetailSnapshot> loadLesson(LessonDetailArgs args) async {
    final lessonId = args.lessonId.trim();
    if (lessonId.isEmpty) {
      throw ArgumentError('lessonId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/students/me/learning/lessons/$lessonId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    final map = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final lessonRaw = map['lesson'];
    final lesson = lessonRaw is Map
        ? lessonRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final hierarchyRaw = map['hierarchy'];
    final hierarchy = hierarchyRaw is Map
        ? hierarchyRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final title = (lesson['title'] ?? args.title ?? 'Lesson').toString().trim();
    final hierarchyParts = <String>[
      for (final key in [
        'module_title',
        'subject_title',
        'chapter_title',
        'topic_title',
      ])
        if ((hierarchy[key]?.toString() ?? '').trim().isNotEmpty)
          hierarchy[key].toString().trim(),
    ];

    return LessonDetailSnapshot(
      lessonId: lesson['id']?.toString() ?? lessonId,
      title: title.isEmpty ? 'Lesson' : title,
      summary: lesson['summary']?.toString(),
      bodyHtml: lesson['body_html']?.toString(),
      estimatedMinutes: _asIntNullable(lesson['estimated_minutes']),
      assessmentId: lesson['assessment_id']?.toString(),
      hierarchyLabel: hierarchyParts.isEmpty ? null : hierarchyParts.join(' · '),
      courseId: hierarchy['course_id']?.toString() ?? args.courseId,
      resources: _parseResources(map['resources']),
      progress: _parseLessonProgress(map['progress']),
    );
  }

  @override
  Future<LessonProgressState> completeLesson(String lessonId) async {
    final id = lessonId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lessonId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.post(
      '/students/me/learning/lessons/$id/complete',
      body: const {},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    return _parseLessonProgress(envelope['data']);
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  LearningCourse? _parseCourse(Map raw) {
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final courseId = map['course_id']?.toString() ?? '';
    if (courseId.isEmpty) return null;

    final title = (map['course_name'] ?? map['program_name'] ?? 'Course')
        .toString()
        .trim();
    final progress = _progressPercent(map['progress']);

    return LearningCourse(
      courseId: courseId,
      title: title.isEmpty ? 'Course' : title,
      enrollmentId: map['enrollment_id']?.toString(),
      programId: map['program_id']?.toString(),
      programName: map['program_name']?.toString(),
      batchName: map['batch_name']?.toString(),
      status: map['status']?.toString(),
      isActive: map['is_active'] == true,
      progressPercent: progress,
    );
  }

  CourseProgressSummary _parseProgress(Object? raw) {
    if (raw is! Map) return const CourseProgressSummary();
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final percent = _progressPercent(
          map['completion_percent'] ?? map['progress_percent'] ?? map['progress'],
        ) ??
        0;
    return CourseProgressSummary(
      completionPercent: percent,
      totalLessons: _asInt(map['total_lessons']),
      completedLessons: _asInt(map['completed_lessons']),
      courseCompleted: map['course_completed'] == true,
    );
  }

  ContinueLearningCursor _parseContinue(Object? raw) {
    if (raw is! Map) {
      return const ContinueLearningCursor(hasCursor: false);
    }
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final lesson = map['lesson'];
    String? lessonTitle;
    if (lesson is Map) {
      lessonTitle = lesson['title']?.toString();
    }
    final hasCursor = map['has_cursor'] == true ||
        (map['lesson_id']?.toString().isNotEmpty ?? false);
    return ContinueLearningCursor(
      hasCursor: hasCursor,
      courseId: map['course_id']?.toString(),
      lessonId: map['lesson_id']?.toString(),
      lessonTitle: lessonTitle,
    );
  }

  LessonProgressState _parseLessonProgress(Object? raw) {
    if (raw is! Map) return const LessonProgressState();
    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    return LessonProgressState(
      status: map['status']?.toString() ?? 'not_started',
      progressPercent: _progressPercent(map['progress_percent']) ?? 0,
      completedAt: map['completed_at']?.toString(),
    );
  }

  List<LessonResource> _parseResources(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final map = item.map((k, v) => MapEntry(k.toString(), v));
          final id = map['id']?.toString() ?? '';
          if (id.isEmpty) return null;
          return LessonResource(
            id: id,
            title: (map['title'] ?? 'Resource').toString(),
            resourceType: (map['resource_type'] ?? 'resource').toString(),
            externalUrl: map['external_url']?.toString(),
            contentText: map['content_text']?.toString(),
            durationSeconds: _asIntNullable(map['duration_seconds']),
            isDownloadable: map['is_downloadable'] == true,
          );
        })
        .whereType<LessonResource>()
        .toList(growable: false);
  }

  List<CourseModule> _parseModules(Object? raw) {
    if (raw is! List) return const [];
    final modules = <CourseModule>[];
    for (final item in raw.whereType<Map>()) {
      final map = item.map((k, v) => MapEntry(k.toString(), v));
      final id = map['id']?.toString() ?? '';
      final title = (map['title'] ?? 'Module').toString();
      if (id.isEmpty) continue;
      modules.add(
        CourseModule(
          id: id,
          title: title,
          lessons: _flattenLessons(map['subjects']),
        ),
      );
    }
    return modules;
  }

  List<CourseLesson> _flattenLessons(Object? subjectsRaw) {
    if (subjectsRaw is! List) return const [];
    final lessons = <CourseLesson>[];

    for (final subject in subjectsRaw.whereType<Map>()) {
      final subjectMap = subject.map((k, v) => MapEntry(k.toString(), v));
      final chapters = subjectMap['chapters'];
      if (chapters is! List) continue;
      for (final chapter in chapters.whereType<Map>()) {
        final chapterMap = chapter.map((k, v) => MapEntry(k.toString(), v));
        final topics = chapterMap['topics'];
        if (topics is! List) continue;
        for (final topic in topics.whereType<Map>()) {
          final topicMap = topic.map((k, v) => MapEntry(k.toString(), v));
          final topicTitle = topicMap['title']?.toString();
          final topicPath = topicMap['topic_path']?.toString() ?? topicTitle;
          final rawLessons = topicMap['lessons'];
          if (rawLessons is! List) continue;
          for (final lesson in rawLessons.whereType<Map>()) {
            final lessonMap =
                lesson.map((k, v) => MapEntry(k.toString(), v));
            final id = lessonMap['id']?.toString() ?? '';
            if (id.isEmpty) continue;
            final progress = lessonMap['progress'];
            String? status;
            int? percent;
            if (progress is Map) {
              final p = progress.map((k, v) => MapEntry(k.toString(), v));
              status = p['status']?.toString();
              percent = _progressPercent(p['progress_percent']);
            }
            lessons.add(
              CourseLesson(
                id: id,
                title: (lessonMap['title'] ?? 'Lesson').toString(),
                topicPath: topicPath,
                status: status,
                progressPercent: percent,
                estimatedMinutes: _asIntNullable(lessonMap['estimated_minutes']),
              ),
            );
          }
        }
      }
    }
    return lessons;
  }

  int? _progressPercent(Object? progress) {
    if (progress is num) {
      return progress.round().clamp(0, 100);
    }
    if (progress is Map) {
      final map = progress.map((k, v) => MapEntry(k.toString(), v));
      for (final key in [
        'percent',
        'percentage',
        'completion_percent',
        'progress_percent',
        'progress',
      ]) {
        final value = map[key];
        if (value is num) return value.round().clamp(0, 100);
      }
    }
    return null;
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _asIntNullable(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }
}
