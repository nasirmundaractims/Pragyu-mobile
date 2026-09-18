import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/notification_preferences/domain/notification_preferences_models.dart';

abstract class NotificationPreferencesGateway {
  Future<NotificationPreferencesSnapshot> load();

  Future<NotificationPreferencesSnapshot> update({
    required NotificationChannelId channel,
    required bool enabled,
  });
}

class NotificationPreferencesRepository
    implements NotificationPreferencesGateway {
  NotificationPreferencesRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<NotificationPreferencesSnapshot> load() async {
    final session = await _requireSession();
    final envelope = await _api.get(
      '/notifications/preferences',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return NotificationPreferencesSnapshot.fromRows(_parseList(envelope['data']));
  }

  @override
  Future<NotificationPreferencesSnapshot> update({
    required NotificationChannelId channel,
    required bool enabled,
  }) async {
    final session = await _requireSession();
    final envelope = await _api.patch(
      '/notifications/preferences',
      body: {
        'channels': [
          {
            'channel': channel.apiValue,
            'is_enabled': enabled,
          },
        ],
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    return NotificationPreferencesSnapshot.fromRows(_parseList(envelope['data']));
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
    return const [];
  }
}
