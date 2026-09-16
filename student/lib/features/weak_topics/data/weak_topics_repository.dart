import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/weak_topics/domain/weak_topics_models.dart';

abstract class WeakTopicsGateway {
  Future<WeakTopicsSnapshot> loadWeakTopics();
}

class WeakTopicsRepository implements WeakTopicsGateway {
  WeakTopicsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<WeakTopicsSnapshot> loadWeakTopics() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for weak topics.',
        statusCode: 0,
      );
    }

    final weakFuture = _listTopics(
      session,
      profileId,
      path: '/learning/mastery/weak-topics',
      status: TopicMasteryStatus.weak,
    );
    final masteryFuture = _listTopics(
      session,
      profileId,
      path: '/learning/mastery',
      status: TopicMasteryStatus.improving,
      deriveStatus: true,
    );
    final strongFuture = _listTopics(
      session,
      profileId,
      path: '/learning/mastery/strong-topics',
      status: TopicMasteryStatus.strong,
    );

    final weak = await weakFuture;
    final mastery = await masteryFuture;
    final strong = await strongFuture;

    return WeakTopicsSnapshot(
      studentProfileId: profileId,
      topics: mergeWeakTopics(weak: weak, mastery: mastery, strong: strong),
    );
  }

  Future<List<WeakTopicItem>> _listTopics(
    SessionContext session,
    String studentProfileId, {
    required String path,
    required TopicMasteryStatus status,
    bool deriveStatus = false,
  }) async {
    try {
      final envelope = await _api.get(
        path,
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is! List) return const [];
      final out = <WeakTopicItem>[];
      for (var i = 0; i < data.length; i++) {
        final row = data[i];
        if (row is! Map) continue;
        final map = row.map((k, v) => MapEntry(k.toString(), v));
        final item = WeakTopicItem.fromJson(
          map,
          status: status,
          index: i,
        );
        out.add(
          deriveStatus
              ? item.copyWith(status: statusFromMastery(item.mastery))
              : item,
        );
      }
      return out;
    } catch (_) {
      return const [];
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
