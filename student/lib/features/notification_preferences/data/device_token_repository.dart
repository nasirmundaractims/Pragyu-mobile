import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';

/// Phase 6 — register / revoke FCM device tokens with the backend.
class DeviceTokenRepository {
  DeviceTokenRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  Future<Map<String, dynamic>> register({
    required String token,
    required String platform,
    String? deviceName,
    String? appVersion,
  }) async {
    final session = await _requireSession();
    final envelope = await _api.post(
      '/notifications/device-tokens',
      body: {
        'token': token,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
        if (appVersion != null) 'app_version': appVersion,
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    final data = envelope['data'];
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  Future<void> revoke(String tokenId) async {
    final session = await _requireSession();
    await _api.delete(
      '/notifications/device-tokens/$tokenId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<void> revokeAll() async {
    final session = await _requireSession();
    await _api.delete(
      '/notifications/device-tokens',
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
}
