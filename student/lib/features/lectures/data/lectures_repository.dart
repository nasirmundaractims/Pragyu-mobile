import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/lectures/domain/lecture_models.dart';

abstract class LecturesGateway {
  Future<LecturesSnapshot> loadLectures({String? courseId});
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId);
  Future<LiveJoinResult> joinLive(String lectureId);
  Future<List<LiveChatMessage>> listLiveChat(String lectureId);
  Future<LiveChatMessage> postLiveChat(String lectureId, String body);
  Future<void> sendAttendanceHeartbeat(String lectureId);
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId);
  Future<LecturePlaybackInfo> loadPlayback(String lectureId);
  Future<RecordedLectureSnapshot> completeRecordedLecture(String lectureId);
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
    final session = await _requireSession();

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

  @override
  Future<LiveLobbySnapshot> loadLiveLobby(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/lectures/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    return _parseLobby(envelope['data'], fallbackId: id);
  }

  @override
  Future<LiveJoinResult> joinLive(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.post(
      '/lectures/$id/live/join',
      body: const {
        'display_name': 'Student',
        'role': 'participant',
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    final map = data is Map
        ? data.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final tokenRaw = map['token'];
    final token = tokenRaw is Map
        ? tokenRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final waiting = map['waiting_room'] == true ||
        token['waiting_room'] == true;
    final mediaToken = token['token']?.toString();
    final hasMedia =
        mediaToken != null && mediaToken.isNotEmpty && !waiting;

    final sessionRaw = map['session'];
    LiveSessionStatus? status;
    if (sessionRaw is Map) {
      status = parseLiveSessionStatus(sessionRaw['status']?.toString());
    }

    return LiveJoinResult(
      inWaitingRoom: waiting,
      hasMediaToken: hasMedia,
      sessionStatus: status,
      mediaUrl: token['url']?.toString(),
    );
  }

  @override
  Future<List<LiveChatMessage>> listLiveChat(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/lectures/$id/live/chat',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => LiveChatMessage.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        )
        .where((m) => m.id.isNotEmpty && m.body.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<LiveChatMessage> postLiveChat(String lectureId, String body) async {
    final id = lectureId.trim();
    final text = body.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }
    if (text.isEmpty) {
      throw ArgumentError('body is required');
    }

    final session = await _requireSession();
    final envelope = await _api.post(
      '/lectures/$id/live/chat',
      body: {'body': text},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is Map) {
      return LiveChatMessage.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return LiveChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      body: text,
      authorRole: 'student',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendAttendanceHeartbeat(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) return;

    final session = await _requireSession();
    await _api.post(
      '/lectures/$id/live/attendance-heartbeat',
      body: const {},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<RecordedLectureSnapshot> loadRecordedLecture(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/lectures/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    return _parseRecorded(envelope['data'], fallbackId: id);
  }

  @override
  Future<LecturePlaybackInfo> loadPlayback(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    final envelope = await _api.get(
      '/lectures/$id/playback',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    final data = envelope['data'];
    if (data is Map) {
      return LecturePlaybackInfo.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const LecturePlaybackInfo();
  }

  @override
  Future<RecordedLectureSnapshot> completeRecordedLecture(
    String lectureId,
  ) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw ArgumentError('lectureId is required');
    }

    final session = await _requireSession();
    await _api.post(
      '/lectures/$id/complete',
      body: const {},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );

    return loadRecordedLecture(id);
  }

  RecordedLectureSnapshot _parseRecorded(
    Object? raw, {
    required String fallbackId,
  }) {
    final map = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final video = map['video'];
    final hasVideo = video is Map && video.isNotEmpty;

    final progress = map['progress'];
    final progressMap = progress is Map
        ? progress.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    int progressPercent = 0;
    final percentRaw =
        progressMap['progress_percent'] ?? progressMap['percent'];
    if (percentRaw is num) {
      progressPercent = percentRaw.round().clamp(0, 100);
    } else {
      progressPercent =
          int.tryParse(percentRaw?.toString() ?? '')?.clamp(0, 100) ?? 0;
    }

    int positionSeconds = 0;
    final positionRaw = progressMap['position_seconds'];
    if (positionRaw is num) {
      positionSeconds = positionRaw.round();
    } else {
      positionSeconds = int.tryParse(positionRaw?.toString() ?? '') ?? 0;
    }

    int? durationSeconds;
    final durationRaw = map['duration_seconds'] ??
        (video is Map ? video['duration_seconds'] : null);
    if (durationRaw is num) {
      durationSeconds = durationRaw.round();
    } else {
      durationSeconds = int.tryParse(durationRaw?.toString() ?? '');
    }

    final isCompleted = progressMap['is_completed'] == true ||
        progressPercent >= 100;

    return RecordedLectureSnapshot(
      lectureId: map['id']?.toString() ?? fallbackId,
      title: (map['title'] ?? 'Lecture').toString(),
      description: map['description']?.toString(),
      courseName: map['course_name']?.toString(),
      subjectName: map['subject_name']?.toString(),
      durationSeconds: durationSeconds,
      accessState: map['access_state']?.toString(),
      progressPercent: progressPercent,
      isCompleted: isCompleted,
      positionSeconds: positionSeconds,
      hasVideo: hasVideo,
    );
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

  LiveLobbySnapshot _parseLobby(Object? raw, {required String fallbackId}) {
    final map = raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final schedule = map['live_schedule'];
    final scheduleMap = schedule is Map
        ? schedule.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    final session = map['live_session'];
    final sessionMap = session is Map
        ? session.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    DateTime? startsAt;
    final startsRaw = scheduleMap['starts_at']?.toString();
    if (startsRaw != null) {
      startsAt = DateTime.tryParse(startsRaw)?.toLocal();
    }

    DateTime? endsAt;
    final endsRaw = scheduleMap['ends_at']?.toString();
    if (endsRaw != null) {
      endsAt = DateTime.tryParse(endsRaw)?.toLocal();
    }

    final rawStatus = sessionMap['status']?.toString();

    return LiveLobbySnapshot(
      lectureId: map['id']?.toString() ?? fallbackId,
      title: (map['title'] ?? 'Live class').toString(),
      courseName: map['course_name']?.toString(),
      subjectName: map['subject_name']?.toString(),
      startsAt: startsAt,
      endsAt: endsAt,
      accessState: map['access_state']?.toString(),
      sessionStatus: parseLiveSessionStatus(rawStatus),
      rawSessionStatus: rawStatus,
    );
  }
}
