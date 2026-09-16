import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/settings/domain/settings_models.dart';

abstract class SettingsGateway {
  Future<SettingsSnapshot> loadSettings();
  Future<void> changePassword(PasswordChangeRequest request);
  Future<void> saveLocaleTimezone(LocaleTimezoneSettings settings);
  Future<void> revokeSession(String sessionId);
  Future<void> revokeOtherSessions();
  Future<void> revokeDevice(String deviceId);
}

class SettingsRepository implements SettingsGateway {
  SettingsRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _api = apiClient ?? ApiClient(),
        _session = sessionService ?? SessionService();

  final ApiClient _api;
  final SessionService _session;

  @override
  Future<SettingsSnapshot> loadSettings() async {
    final session = await _requireSession();

    final profileFuture = _loadLocaleTimezone(session);
    final sessionsFuture = _loadSessions(session);
    final devicesFuture = _loadDevices(session);

    final localeTimezone = await profileFuture;
    final sessionsResult = await sessionsFuture;
    final devicesResult = await devicesFuture;

    return SettingsSnapshot(
      localeTimezone: localeTimezone,
      sessions: sessionsResult.items,
      devices: devicesResult.items,
      sessionsUnavailable: sessionsResult.unavailable,
      devicesUnavailable: devicesResult.unavailable,
    );
  }

  @override
  Future<void> changePassword(PasswordChangeRequest request) async {
    final validation = validateNewPassword(
      request.password,
      request.passwordConfirmation,
    );
    if (validation != null) {
      throw ApiException(message: validation, statusCode: 0);
    }
    if (request.currentPassword.trim().isEmpty) {
      throw ApiException(
        message: 'Current password is required.',
        statusCode: 0,
      );
    }

    final session = await _requireSession();
    await _api.post(
      '/auth/change-password',
      body: {
        'current_password': request.currentPassword,
        'password': request.password,
        'password_confirmation': request.passwordConfirmation,
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> saveLocaleTimezone(LocaleTimezoneSettings settings) async {
    final session = await _requireSession();
    await _api.patch(
      '/users/me/profile',
      body: {
        'locale': settings.locale.trim().isEmpty ? null : settings.locale.trim(),
        'timezone':
            settings.timezone.trim().isEmpty ? null : settings.timezone.trim(),
      },
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
    try {
      await _api.put(
        '/localization/preference',
        body: {'locale': settings.locale.trim()},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
    } catch (_) {
      // Profile locale is the source of truth; localization preference is best-effort.
    }
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    final session = await _requireSession();
    await _api.delete(
      '/auth/sessions/$sessionId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> revokeOtherSessions() async {
    final session = await _requireSession();
    await _api.post(
      '/auth/sessions/revoke-others',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    final session = await _requireSession();
    await _api.delete(
      '/auth/devices/$deviceId',
      accessToken: session.accessToken,
      organizationId: session.organizationId,
    );
  }

  Future<LocaleTimezoneSettings> _loadLocaleTimezone(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/users/me/profile',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = _asMap(envelope['data']);
      return LocaleTimezoneSettings(
        locale: (data['locale']?.toString().trim().isNotEmpty == true)
            ? data['locale'].toString().trim()
            : 'en',
        timezone: (data['timezone']?.toString().trim().isNotEmpty == true)
            ? data['timezone'].toString().trim()
            : 'Asia/Kolkata',
      );
    } catch (_) {
      return const LocaleTimezoneSettings();
    }
  }

  Future<({List<AuthSessionItem> items, bool unavailable})> _loadSessions(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/auth/sessions',
        query: const {'page': '1', 'per_page': '50'},
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final rows = _extractItems(envelope['data']);
      final items = rows
          .map(AuthSessionItem.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      return (items: items, unavailable: false);
    } catch (_) {
      return (items: const <AuthSessionItem>[], unavailable: true);
    }
  }

  Future<({List<TrustedDeviceItem> items, bool unavailable})> _loadDevices(
    SessionContext session,
  ) async {
    try {
      final envelope = await _api.get(
        '/auth/devices',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final rows = _extractItems(envelope['data']);
      final items = rows
          .map(TrustedDeviceItem.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      return (items: items, unavailable: false);
    } catch (_) {
      return (items: const <TrustedDeviceItem>[], unavailable: true);
    }
  }

  List<Map<String, dynamic>> _extractItems(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    final map = _asMap(raw);
    final items = map['items'] ?? map['data'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((row) => row.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
    return const [];
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
