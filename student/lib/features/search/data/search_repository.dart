import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/search/domain/search_models.dart';

abstract class SearchGateway {
  Future<QuickSearchCatalog> loadCatalog();
  Future<List<SearchHit>> searchMaterials(String query);
  QuickSearchResults filterCatalog(QuickSearchCatalog catalog, String query);
}

class SearchRepository implements SearchGateway {
  SearchRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<QuickSearchCatalog> loadCatalog() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }

    final coursesFuture = _loadCourses(session);
    final testsFuture = _loadTests(session);
    final courses = await coursesFuture;
    final tests = await testsFuture;
    return QuickSearchCatalog(courses: courses, tests: tests);
  }

  @override
  Future<List<SearchHit>> searchMaterials(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final session = await _session.read();
    if (session == null) return const [];

    try {
      final envelope = await _api.get(
        '/students/me/learning/search',
        query: {'q': trimmed},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) {
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            final type = map['type']?.toString() ?? 'material';
            final id = (map['lesson_id'] ?? map['id'])?.toString() ?? '';
            final title = map['title']?.toString() ?? 'Material';
            if (id.isEmpty) return null;
            // Prefer lesson/pdf/notes for "material" jump targets.
            if (type != 'lesson' &&
                type != 'pdf' &&
                type != 'notes' &&
                type != 'resource') {
              return null;
            }
            return SearchHit(
              id: id,
              title: title,
              kind: SearchHitKind.material,
              subtitle: map['topic_path']?.toString(),
              materialType: type,
            );
          })
          .whereType<SearchHit>()
          .take(12)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  QuickSearchResults filterCatalog(QuickSearchCatalog catalog, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.length < 2) {
      return const QuickSearchResults();
    }
    bool matches(SearchHit hit) {
      final haystack = [
        hit.title,
        hit.subtitle ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(trimmed);
    }

    return QuickSearchResults(
      courses: catalog.courses.where(matches).take(8).toList(growable: false),
      tests: catalog.tests.where(matches).take(8).toList(growable: false),
    );
  }

  Future<List<SearchHit>> _loadCourses(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me/account/courses',
        query: const {'status': 'all'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((item) {
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            final id = map['course_id']?.toString() ?? '';
            final title = (map['course_name'] ??
                    map['program_name'] ??
                    'Course')
                .toString();
            if (id.isEmpty) return null;
            final batch = map['batch_name']?.toString();
            final program = map['program_name']?.toString();
            return SearchHit(
              id: id,
              title: title,
              kind: SearchHitKind.course,
              subtitle: [
                if (program != null &&
                    program.isNotEmpty &&
                    program != title)
                  program,
                if (batch != null && batch.isNotEmpty) batch,
              ].join(' · '),
            );
          })
          .whereType<SearchHit>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<SearchHit>> _loadTests(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/assessments',
        query: const {
          'page': '1',
          'per_page': '50',
          'status': 'published',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((item) {
            final map = item.map((k, v) => MapEntry(k.toString(), v));
            final id = map['id']?.toString() ?? '';
            final title = map['title']?.toString() ?? 'Assessment';
            if (id.isEmpty) return null;
            return SearchHit(
              id: id,
              title: title,
              kind: SearchHitKind.test,
              subtitle: map['type']?.toString(),
            );
          })
          .whereType<SearchHit>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
