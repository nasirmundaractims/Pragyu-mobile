import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/calendar/domain/calendar_models.dart';
import 'package:student_mobile/features/home/domain/home_models.dart';

abstract class CalendarGateway {
  Future<CalendarSnapshot> loadCalendar({
    int horizonDays = 14,
    DateTime? now,
  });
}

class CalendarRepository implements CalendarGateway {
  CalendarRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  static const defaultHorizonDays = 14;

  @override
  Future<CalendarSnapshot> loadCalendar({
    int horizonDays = defaultHorizonDays,
    DateTime? now,
  }) async {
    final session = await _requireSession();
    final clock = now ?? DateTime.now();
    final start = calendarHorizonStart(clock);
    final end = calendarHorizonEnd(clock, horizonDays: horizonDays);

    final profileId = await _loadStudentProfileId(session);
    final assessmentsFuture = _loadAssessmentEvents(
      session,
      start: start,
      end: end,
    );
    final lecturesFuture = profileId == null
        ? Future.value(const <CalendarEvent>[])
        : _loadLiveEvents(
            session,
            profileId,
            start: start,
            end: end,
            now: clock,
          );

    final assessments = await assessmentsFuture;
    final lectures = await lecturesFuture;

    return CalendarSnapshot.fromEvents(
      [...lectures, ...assessments],
      horizonDays: horizonDays,
    );
  }

  Future<List<CalendarEvent>> _loadLiveEvents(
    SessionContext session,
    String studentProfileId, {
    required DateTime start,
    required DateTime end,
    required DateTime now,
  }) async {
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

      final events = <CalendarEvent>[];
      for (final raw in data.whereType<Map>()) {
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final lecture = HomeLecture.fromJson(map);
        if (lecture.id.isEmpty) continue;
        if ((lecture.lectureType ?? '').toLowerCase() != 'live' &&
            !lecture.isLiveNow) {
          continue;
        }

        final startsAt = lecture.startsAt;
        final liveNow = lecture.isLiveNow;
        if (startsAt == null && !liveNow) continue;

        final when = startsAt ?? now;
        final inHorizon = isWithinCalendarHorizon(when, start: start, end: end);
        if (!inHorizon && !liveNow) continue;

        final status = (lecture.sessionStatus ?? '').toLowerCase();
        String? subtitle = lecture.subjectName ?? lecture.courseName;
        if (status == 'live') {
          subtitle = subtitle == null || subtitle.isEmpty
              ? 'Live now'
              : '$subtitle · Live now';
        } else if (status == 'waiting') {
          subtitle = subtitle == null || subtitle.isEmpty
              ? 'Waiting room'
              : '$subtitle · Waiting room';
        }

        events.add(
          CalendarEvent(
            id: 'live-${lecture.id}',
            kind: CalendarEventKind.live,
            title: lecture.title,
            startsAt: when,
            sourceId: lecture.id,
            subtitle: subtitle,
            isLiveNow: liveNow,
          ),
        );
      }
      return events;
    } catch (_) {
      return const [];
    }
  }

  Future<List<CalendarEvent>> _loadAssessmentEvents(
    SessionContext session, {
    required DateTime start,
    required DateTime end,
  }) async {
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

      final events = <CalendarEvent>[];
      for (final raw in data.whereType<Map>()) {
        final map = raw.map((k, v) => MapEntry(k.toString(), v));
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final when = assessmentWhen(map);
        if (when == null) continue;
        if (!isWithinCalendarHorizon(when, start: start, end: end)) continue;

        events.add(
          CalendarEvent(
            id: 'test-$id',
            kind: CalendarEventKind.test,
            title: (map['title'] ?? 'Assessment').toString(),
            startsAt: when,
            sourceId: id,
            subtitle: assessmentWhenLabel(map),
          ),
        );
      }
      return events;
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
