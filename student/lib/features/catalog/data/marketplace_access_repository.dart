import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/session/session_service.dart';
import 'package:student_mobile/features/catalog/domain/marketplace_access_models.dart';

abstract class MarketplaceAccessGateway {
  Future<MarketplaceAccess> fetch();
}

/// Calls `GET /students/me/marketplace-access` (parity with student-web).
class MarketplaceAccessRepository implements MarketplaceAccessGateway {
  MarketplaceAccessRepository({
    ApiClient? apiClient,
    SessionService? sessionService,
  })  : _apiClient = apiClient,
        _sessionService = sessionService;

  ApiClient? _apiClient;
  SessionService? _sessionService;

  ApiClient get _api => _apiClient ??= ApiClient();
  SessionService get _session => _sessionService ??= SessionService();

  @override
  Future<MarketplaceAccess> fetch() async {
    try {
      final session = await _session.read();
      if (session == null) {
        return MarketplaceAccess.unknownOpen;
      }

      final envelope = await _api.get(
        '/students/me/marketplace-access',
        accessToken: session.accessToken,
        organizationId: session.organizationId,
      );
      final data = envelope['data'];
      if (data is Map) {
        return MarketplaceAccess.fromJson(
          data.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      if (envelope.containsKey('available')) {
        return MarketplaceAccess.fromJson(
          envelope.map((key, value) => MapEntry(key, value)),
        );
      }
      return MarketplaceAccess.unknownOpen;
    } catch (_) {
      // Fail-open: match student-web (query error → available true).
      // Also covers missing AppConfig in widget tests.
      return MarketplaceAccess.unknownOpen;
    }
  }
}
