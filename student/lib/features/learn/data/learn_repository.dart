import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/learn/domain/learn_models.dart';

abstract class LearnGateway {
  Future<MyLearningSnapshot> loadMyLearning();
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
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }

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

    // Active first, then by title.
    final sorted = [...courses]..sort((a, b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    return MyLearningSnapshot(courses: sorted);
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

  int? _progressPercent(Object? progress) {
    if (progress is num) {
      return progress.round().clamp(0, 100);
    }
    if (progress is Map) {
      final map = progress.map((k, v) => MapEntry(k.toString(), v));
      for (final key in ['percent', 'percentage', 'completion_percent', 'progress']) {
        final value = map[key];
        if (value is num) return value.round().clamp(0, 100);
      }
    }
    return null;
  }
}
