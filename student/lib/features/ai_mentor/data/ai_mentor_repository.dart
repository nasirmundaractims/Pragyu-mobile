import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/ai_mentor/domain/ai_mentor_models.dart';

abstract class AiMentorGateway {
  Future<MentorChatSnapshot> loadChat();

  Future<MentorSession> startSession({
    required String studentProfileId,
    Map<String, dynamic>? context,
  });

  Future<MentorSession> getSession(String sessionId);

  Future<MentorSession> sendMessage({
    required String sessionId,
    required String content,
    Map<String, dynamic>? context,
  });
}

class AiMentorRepository implements AiMentorGateway {
  AiMentorRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<MentorChatSnapshot> loadChat() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for AI Mentor.',
        statusCode: 0,
      );
    }

    final weakFuture = _loadWeakTopics(session, profileId);
    final recsFuture = _loadRecommendationTitles(session, profileId);
    final sessions = await _listSessions(session, profileId);
    final weakTopics = await weakFuture;
    final recommendationTitles = await recsFuture;

    MentorSession? active;
    if (sessions.isNotEmpty) {
      final first = sessions.first;
      try {
        active = await getSession(first.id);
      } catch (_) {
        active = first;
      }
    }

    return MentorChatSnapshot(
      studentProfileId: profileId,
      session: active,
      sessions: sessions,
      weakTopics: weakTopics,
      recommendationTitles: recommendationTitles,
    );
  }

  @override
  Future<MentorSession> startSession({
    required String studentProfileId,
    Map<String, dynamic>? context,
  }) async {
    final id = studentProfileId.trim();
    if (id.isEmpty) {
      throw ArgumentError('studentProfileId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/coach/sessions',
      body: {
        'student_profile_id': id,
        'context': context ?? const <String, dynamic>{},
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final created = MentorSession.fromJson(_asMap(envelope['data']));
    if (created.id.isEmpty) {
      throw ApiException(
        message: 'Unable to start mentor session.',
        statusCode: 0,
      );
    }
    return created;
  }

  @override
  Future<MentorSession> getSession(String sessionId) async {
    final id = sessionId.trim();
    if (id.isEmpty) {
      throw ArgumentError('sessionId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.get(
      '/coach/sessions/$id',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return MentorSession.fromJson(_asMap(envelope['data']));
  }

  @override
  Future<MentorSession> sendMessage({
    required String sessionId,
    required String content,
    Map<String, dynamic>? context,
  }) async {
    final id = sessionId.trim();
    final text = content.trim();
    if (id.isEmpty) {
      throw ArgumentError('sessionId is required');
    }
    if (text.isEmpty) {
      throw ArgumentError('content is required');
    }
    final session = await _requireSession();
    final body = <String, dynamic>{
      'content': text,
      if (context != null && context.isNotEmpty) 'context': context,
    };
    final envelope = await _api.post(
      '/coach/sessions/$id/messages',
      body: body,
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return MentorSession.fromJson(_asMap(envelope['data']));
  }

  Future<List<MentorSession>> _listSessions(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/coach/sessions',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (row) => MentorSession.fromJson(
              row.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _loadWeakTopics(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/learning/mastery/weak-topics',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _topicTitles(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _loadRecommendationTitles(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/learning/recommendations',
        query: {
          'student_profile_id': studentProfileId,
          'page': '1',
          'per_page': '5',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _topicTitles(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  List<String> _topicTitles(Object? data) {
    if (data is! List) return const [];
    final out = <String>[];
    for (final row in data) {
      if (row is String) {
        final value = row.trim();
        if (value.isNotEmpty) out.add(value);
        continue;
      }
      if (row is Map) {
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        final title = (map['title'] ??
                map['topic'] ??
                map['name'] ??
                map['label'] ??
                map['weak_topic'])
            ?.toString()
            .trim();
        if (title != null && title.isNotEmpty) out.add(title);
      }
    }
    return out;
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

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
