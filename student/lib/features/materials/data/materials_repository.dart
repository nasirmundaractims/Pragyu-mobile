import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/materials/domain/material_models.dart';

abstract class MaterialsGateway {
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  });
}

class MaterialsRepository implements MaterialsGateway {
  MaterialsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<StudyMaterialsSnapshot> loadMaterials({
    String? courseId,
    String? courseTitle,
  }) async {
    final session = await _requireSession();
    final trimmedCourse = courseId?.trim();

    if (trimmedCourse != null && trimmedCourse.isNotEmpty) {
      final items = await _listForCourse(
        session,
        courseId: trimmedCourse,
        courseTitle: courseTitle,
      );
      return StudyMaterialsSnapshot(items: items);
    }

    // Student list API requires course_id — fan-out enrolled courses.
    final courses = await _loadEnrolledCourses(session);
    if (courses.isEmpty) {
      return const StudyMaterialsSnapshot();
    }

    final byId = <String, StudyMaterial>{};
    for (final course in courses) {
      try {
        final items = await _listForCourse(
          session,
          courseId: course.id,
          courseTitle: course.title,
        );
        for (final item in items) {
          byId.putIfAbsent(item.id, () => item);
        }
      } on ApiException {
        // Skip courses that fail individually.
      } catch (_) {
        // Best-effort fan-out.
      }
    }

    final merged = byId.values.toList(growable: false)
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

    return StudyMaterialsSnapshot(items: merged);
  }

  Future<List<StudyMaterial>> _listForCourse(
    SessionContext session, {
    required String courseId,
    String? courseTitle,
  }) async {
    final envelope = await _api.get(
      '/students/me/study-materials',
      query: {'course_id': courseId},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) {
      return const [];
    }

    final title = courseTitle?.trim();
    return data
        .whereType<Map>()
        .map(
          (item) => StudyMaterial.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
            courseId: courseId,
            courseTitle: (title != null && title.isNotEmpty) ? title : null,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<({String id, String title})>> _loadEnrolledCourses(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/students/me/account/courses',
        query: const {'status': 'all'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) {
        return const [];
      }

      final courses = <({String id, String title})>[];
      for (final raw in data) {
        if (raw is! Map) continue;
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final id = map['course_id']?.toString() ??
            map['id']?.toString() ??
            '';
        if (id.isEmpty) continue;
        final title = (map['title'] ??
                map['course_name'] ??
                map['name'] ??
                'Course')
            .toString()
            .trim();
        courses.add((id: id, title: title.isEmpty ? 'Course' : title));
      }
      return courses;
    } on ApiException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }
}
