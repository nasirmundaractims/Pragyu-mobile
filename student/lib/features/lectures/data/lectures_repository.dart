import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

abstract class LecturesGateway {
  Future<LecturesSnapshot> loadLectures({String? courseId});
}

class LecturesRepository implements LecturesGateway {
  LecturesRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<LecturesSnapshot> loadLectures({String? courseId}) async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }

    final profileId = await _loadStudentProfileId(session);
    if (profileId == null) {
      return const LecturesSnapshot();
    }

    final query = <String, String>{
      'status': 'published',
      'student_profile_id': profileId,
    };
    final trimmedCourse = courseId?.trim();
    if (trimmedCourse != null && trimmedCourse.isNotEmpty) {
      query['course_id'] = trimmedCourse;
    }

    final envelope = await _api.get(
      '/lectures',
      query: query,
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) {
      return const LecturesSnapshot();
    }

    final items = data
        .whereType<Map>()
        .map(
          (item) => LectureItem.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);

    return LecturesSnapshot.fromItems(items);
  }

  Future<String?> _loadStudentProfileId(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      final map = data is Map
          ? data.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};
      final id = map['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
