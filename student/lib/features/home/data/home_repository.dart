import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/home/domain/due_state.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';

abstract class HomeGateway {
  Future<HomeSnapshot> loadHome();
  Future<TodaySnapshot> loadToday();
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
    final session = await _requireSession();
    final userFuture = _loadUser(session);
    final profileFuture = _loadStudentProfileId(session);
    final unreadFuture = _loadUnreadCount(session);
    final assessmentsFuture = _loadAssessments(session);

    final user = await userFuture;
    final profileId = await profileFuture;
    final unread = await unreadFuture;
    final assessments = await assessmentsFuture;
    final lectures = profileId == null
        ? const <HomeLecture>[]
        : await _loadLectures(session, profileId);

    final dueAssessments = assessments
        .where((item) => item.due?.isActionable ?? false)
        .toList()
      ..sort(_compareAssessments);

    return HomeSnapshot(
      user: user,
      nextLecture: _pickNextLecture(lectures),
      dueAssessments: dueAssessments.take(5).toList(growable: false),
      unreadCount: unread,
    );
  }

  @override
  Future<TodaySnapshot> loadToday() async {
    final session = await _requireSession();
    final now = DateTime.now();
    final profileId = await _loadStudentProfileId(session);
    final assessments = await _loadAssessments(session);
    final lectures = profileId == null
        ? const <HomeLecture>[]
        : await _loadLectures(session, profileId);

    final classes = lectures.where((lecture) {
      if (lecture.isLiveNow) return true;
      final starts = lecture.startsAt;
      return starts != null && isSameLocalDay(starts, now);
    }).toList()
      ..sort((a, b) {
        if (a.isLiveNow != b.isLiveNow) {
          return a.isLiveNow ? -1 : 1;
        }
        final sa = a.startsAt;
        final sb = b.startsAt;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });

    final deadlines = assessments.where((item) {
      final urgency = item.due?.urgency;
      return urgency == DueUrgency.dueToday ||
          urgency == DueUrgency.overdue ||
          urgency == DueUrgency.endsSoon;
    }).toList()
      ..sort(_compareAssessments);

    return TodaySnapshot(
      day: now,
      classes: classes,
      deadlines: deadlines,
    );
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
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

  Future<List<HomeAssessment>> _loadAssessments(SessionContext session) async {
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
      return data
          .whereType<Map>()
          .map(
            (item) => HomeAssessment.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
              now: now,
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<HomeLecture>> _loadLectures(
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
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => HomeLecture.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static HomeLecture? _pickNextLecture(List<HomeLecture> lectures) {
    final live = lectures.where((l) => l.sessionStatus == 'live').toList();
    if (live.isNotEmpty) return live.first;

    final waiting =
        lectures.where((l) => l.sessionStatus == 'waiting').toList();
    if (waiting.isNotEmpty) return waiting.first;

    final upcoming = lectures.where((l) => l.startsAt != null).toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
    final now = DateTime.now();
    for (final lecture in upcoming) {
      if (!lecture.startsAt!.isBefore(now.subtract(const Duration(hours: 1)))) {
        return lecture;
      }
    }
    return upcoming.isEmpty ? null : upcoming.first;
  }

  static int _compareAssessments(HomeAssessment a, HomeAssessment b) {
    final rankA = _urgencyRank(a.due?.urgency);
    final rankB = _urgencyRank(b.due?.urgency);
    if (rankA != rankB) return rankA.compareTo(rankB);
    final da = a.deadlineAt;
    final db = b.deadlineAt;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
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
