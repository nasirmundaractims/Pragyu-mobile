import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';

abstract class HomeGateway {
  Future<HomeSnapshot> loadHome();
}

class HomeRepository implements HomeGateway {
  HomeRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<HomeSnapshot> loadHome() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }

    final userFuture = _loadUser(session);
    final profileFuture = _loadStudentProfileId(session);
    final unreadFuture = _loadUnreadCount(session);
    final assessmentsFuture = _loadDueAssessments(session);

    final user = await userFuture;
    final profileId = await profileFuture;
    final unread = await unreadFuture;
    final dueAssessments = await assessmentsFuture;
    final nextLecture = profileId == null
        ? null
        : await _loadNextLecture(session, profileId);

    return HomeSnapshot(
      user: user,
      nextLecture: nextLecture,
      dueAssessments: dueAssessments,
      unreadCount: unread,
    );
  }

  Future<AuthUser> _loadUser(SessionContext session) async {
    if (session.cachedUser != null) {
      return session.cachedUser!;
    }
    try {
      final envelope = await _api.get(
        '/auth/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      return AuthUser.fromJson(data);
    } catch (_) {
      return const AuthUser(id: '', email: '', firstName: 'Student');
    }
  }

  Future<String?> _loadStudentProfileId(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/students/me',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final id = data['id']?.toString();
      return (id == null || id.isEmpty) ? null : id;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int> _loadUnreadCount(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/notifications/unread-count',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      final raw = data['unread_count'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<HomeAssessment>> _loadDueAssessments(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/assessments',
        query: const {
          'page': '1',
          'per_page': '50',
          'status': 'published',
          'sort': '-scheduled_at',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      final now = DateTime.now();
      final mapped = data
          .whereType<Map>()
          .map(
            (item) => HomeAssessment.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
              now: now,
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .where((item) => item.due?.isActionable ?? false)
          .toList();

      mapped.sort((a, b) {
        final rankA = _urgencyRank(a.due?.urgency);
        final rankB = _urgencyRank(b.due?.urgency);
        if (rankA != rankB) return rankA.compareTo(rankB);
        final da = a.deadlineAt;
        final db = b.deadlineAt;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
      return mapped.take(5).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<HomeLecture?> _loadNextLecture(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/lectures',
        query: {
          'status': 'published',
          'student_profile_id': studentProfileId,
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return null;

      final lectures = data
          .whereType<Map>()
          .map(
            (item) => HomeLecture.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();

      final live = lectures.where((l) => l.sessionStatus == 'live').toList();
      if (live.isNotEmpty) return live.first;

      final waiting =
          lectures.where((l) => l.sessionStatus == 'waiting').toList();
      if (waiting.isNotEmpty) return waiting.first;

      final upcoming = lectures
          .where((l) => l.startsAt != null)
          .toList()
        ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
      final now = DateTime.now();
      for (final lecture in upcoming) {
        if (!lecture.startsAt!.isBefore(now.subtract(const Duration(hours: 1)))) {
          return lecture;
        }
      }
      return upcoming.isEmpty ? null : upcoming.first;
    } catch (_) {
      return null;
    }
  }

  static int _urgencyRank(DueUrgency? urgency) {
    switch (urgency) {
      case DueUrgency.endsSoon:
        return 0;
      case DueUrgency.overdue:
        return 1;
      case DueUrgency.dueToday:
        return 2;
      case DueUrgency.dueTomorrow:
        return 3;
      case DueUrgency.none:
      case null:
        return 9;
    }
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }
}
