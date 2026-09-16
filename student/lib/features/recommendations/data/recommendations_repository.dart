import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/recommendations/domain/recommendations_models.dart';

abstract class RecommendationsGateway {
  Future<RecommendationsSnapshot> loadRecommendations();

  Future<List<RecommendationItem>> generateRecommendations({
    required String studentProfileId,
  });

  Future<void> recordOutcome({
    required String recommendationId,
    required String outcome,
  });
}

class RecommendationsRepository implements RecommendationsGateway {
  RecommendationsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<RecommendationsSnapshot> loadRecommendations() async {
    final session = await _requireSession();
    final profileId = await _loadStudentProfileId(session);
    if (profileId == null || profileId.isEmpty) {
      throw ApiException(
        message: 'Student profile is required for recommendations.',
        statusCode: 0,
      );
    }

    final itemsFuture = _listRecommendations(session, profileId);
    final weakFuture = _weakTopicCount(session, profileId);
    final items = await itemsFuture;
    final weakCount = await weakFuture;

    return RecommendationsSnapshot(
      studentProfileId: profileId,
      items: items,
      weakTopicCount: weakCount,
    );
  }

  @override
  Future<List<RecommendationItem>> generateRecommendations({
    required String studentProfileId,
  }) async {
    final id = studentProfileId.trim();
    if (id.isEmpty) {
      throw ArgumentError('studentProfileId is required');
    }
    final session = await _requireSession();
    final envelope = await _api.post(
      '/learning/recommendations/generate',
      body: {'student_profile_id': id},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return _parseItems(envelope['data']);
  }

  @override
  Future<void> recordOutcome({
    required String recommendationId,
    required String outcome,
  }) async {
    final id = recommendationId.trim();
    if (id.isEmpty) {
      throw ArgumentError('recommendationId is required');
    }
    final session = await _requireSession();
    await _api.post(
      '/learning/recommendations/$id/outcome',
      body: {'outcome': outcome},
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<List<RecommendationItem>> _listRecommendations(
    SessionContext session,
    String studentProfileId,
  ) async {
    try {
      final envelope = await _api.get(
        '/learning/recommendations',
        query: {'student_profile_id': studentProfileId},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseItems(envelope['data']);
    } catch (_) {
      return const [];
    }
  }

  Future<int> _weakTopicCount(
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
      final data = envelope['data'];
      return data is List ? data.length : 0;
    } catch (_) {
      return 0;
    }
  }

  List<RecommendationItem> _parseItems(Object? data) {
    if (data is! List) return const [];
    final out = <RecommendationItem>[];
    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      if (row is! Map) continue;
      out.add(
        RecommendationItem.fromJson(
          row.map((k, v) => MapEntry(k.toString(), v)),
          index: i,
        ),
      );
    }
    out.sort((a, b) {
      final byPriority = b.priorityWeight.compareTo(a.priorityWeight);
      if (byPriority != 0) return byPriority;
      return (b.confidence ?? 0).compareTo(a.confidence ?? 0);
    });
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
