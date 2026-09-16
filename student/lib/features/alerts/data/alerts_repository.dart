import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/alerts/domain/alerts_models.dart';

abstract class AlertsGateway {
  Future<AlertsSnapshot> loadAlerts();

  Future<int> unreadCount();

  Future<void> markRead(AlertItem item);

  Future<void> markAllRead();
}

class AlertsRepository implements AlertsGateway {
  AlertsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<AlertsSnapshot> loadAlerts() async {
    final session = await _requireSession();
    final notificationsFuture = _loadNotifications(session);
    final inboxFuture = _loadInbox(session);
    final unreadFuture = unreadCount();

    final notifications = await notificationsFuture;
    final inbox = await inboxFuture;
    final unread = await unreadFuture;

    final seen = <String>{};
    final merged = <AlertItem>[];
    for (final item in [...notifications, ...inbox]) {
      if (item.id.isEmpty) {
        merged.add(item);
        continue;
      }
      if (seen.contains(item.id)) continue;
      seen.add(item.id);
      merged.add(item);
    }

    merged.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    final pageUnread = merged.where((item) => !item.isRead).length;
    return AlertsSnapshot(
      items: merged,
      unreadCount: unread > 0 ? unread : pageUnread,
    );
  }

  @override
  Future<int> unreadCount() async {
    final session = await _requireSession();
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

  @override
  Future<void> markRead(AlertItem item) async {
    final id = item.id.trim();
    if (id.isEmpty) return;
    final session = await _requireSession();
    switch (item.source) {
      case AlertSource.notification:
        await _api.post(
          '/notifications/$id/read',
          accessToken: session.accessToken,
          organizationId: session.organizationId,
        );
      case AlertSource.inbox:
        await _api.post(
          '/engagement/inbox/$id/read',
          accessToken: session.accessToken,
          organizationId: session.organizationId,
        );
    }
  }

  @override
  Future<void> markAllRead() async {
    final session = await _requireSession();
    await _api.post(
      '/notifications/read-all',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<List<AlertItem>> _loadNotifications(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/notifications',
        query: const {
          'page': '1',
          'per_page': '50',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data'])
          .map(AlertItem.fromNotificationJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  Future<List<AlertItem>> _loadInbox(SessionContext session) async {
    try {
      final envelope = await _api.get(
        '/engagement/inbox',
        query: const {
          'page': '1',
          'per_page': '50',
        },
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      return _parseList(envelope['data'])
          .map(AlertItem.fromInboxJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on ApiException {
      return const [];
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

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }
}
