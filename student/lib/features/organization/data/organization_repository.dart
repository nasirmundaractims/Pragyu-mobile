import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/features/auth/data/secure_token_store.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/organization/data/secure_tenant_store.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

abstract class OrganizationGateway {
  Future<List<OrganizationSummary>> listOrganizations();
  Future<void> selectOrganization(OrganizationSummary organization);
  Future<String?> readActiveOrganizationId();
}

class OrganizationRepository implements OrganizationGateway {
  OrganizationRepository({
    ApiClient? apiClient,
    TokenStore? tokenStore,
    TenantStore? tenantStore,
  })  : _api = apiClient ?? ApiClient(),
        _tokens = tokenStore ?? SecureTokenStore(),
        _tenant = tenantStore ?? SecureTenantStore();

  final ApiClient _api;
  final TokenStore _tokens;
  final TenantStore _tenant;

  @override
  Future<List<OrganizationSummary>> listOrganizations() async {
    final accessToken = await _tokens.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Signed-in session required to load organizations.');
    }

    final envelope = await _api.get(
      '/organizations',
      query: const {'per_page': '100'},
      accessToken: accessToken,
    );

    final data = envelope['data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map(
          (item) => OrganizationSummary.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((org) => org.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> selectOrganization(OrganizationSummary organization) {
    return _tenant.saveActiveOrganization(
      id: organization.id,
      name: organization.name,
      type: organization.type,
    );
  }

  @override
  Future<String?> readActiveOrganizationId() =>
      _tenant.readActiveOrganizationId();
}
