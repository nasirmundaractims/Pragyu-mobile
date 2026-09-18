import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/announcements/domain/announcements_models.dart';

abstract class AnnouncementsGateway {
  Future<AnnouncementsSnapshot> loadAnnouncements();

  Future<AnnouncementItem?> findById(String announcementId);

  Future<void> markRead(String announcementId);
}

class AnnouncementsRepository implements AnnouncementsGateway {
  AnnouncementsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<AnnouncementsSnapshot> loadAnnouncements() async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/engagement/announcements',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final items = _parseList(envelope['data'])
        .map(AnnouncementItem.fromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
    return AnnouncementsSnapshot(items: items);
  }

  @override
  Future<AnnouncementItem?> findById(String announcementId) async {
    final id = announcementId.trim();
    if (id.isEmpty) return null;
    final snapshot = await loadAnnouncements();
    for (final item in snapshot.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<void> markRead(String announcementId) async {
    final id = announcementId.trim();
    if (id.isEmpty) return;
    final session = await _requireSession();
    await _api.post(
      '/engagement/announcements/$id/read',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  static List<Map<String, dynamic>> _parseList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      final nested = map['items'] ?? map['data'];
      if (nested is List) {
        return nested
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
    }
    return const [];
  }
}
