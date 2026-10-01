import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/notification_preferences/domain/notification_preferences_models.dart';
import 'package:student_mobile/features/notification_preferences/domain/outbound_channel_capability.dart';
import 'package:student_mobile/features/notification_preferences/domain/push_delivery.dart';

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
    _applyCapabilities(envelope['data']);
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
    _applyCapabilities(envelope['data']);
    return NotificationPreferencesSnapshot.fromRows(_parseList(envelope['data']));
  }

  Future<SessionContext> _requireSession() async {
    final session = await _session.read();
    if (session == null) {
      throw StateError('Signed-in session with institute is required.');
    }
    return session;
  }

  static void _applyCapabilities(Object? raw) {
    if (raw is! Map) return;
    final capabilities = raw['capabilities'];
    if (capabilities is! Map) return;
    final push = capabilities['push'];
    if (push is Map) {
      PushDelivery.osPushAvailable = push['configured'] == true;
    }
    final sms = capabilities['sms'];
    if (sms is Map) {
      OutboundChannelCapability.smsConfigured = sms['configured'] == true;
    }
    final whatsapp = capabilities['whatsapp'];
    if (whatsapp is Map) {
      OutboundChannelCapability.whatsappConfigured =
          whatsapp['configured'] == true;
    }
  }

  static List<Map<String, dynamic>> _parseList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    // Phase 4 object shape: { channels, categories, quiet_hours }
    if (raw is Map) {
      final channels = raw['channels'];
      if (channels is List) {
        return _parseList(channels);
      }
    }
    return const [];
  }
}
