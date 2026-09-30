import 'package:student_mobile/core/network/api_client.dart';
import 'package:student_mobile/core/network/api_exception.dart';
import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/catalog/data/marketplace_access_service.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';
import 'package:student_mobile/features/organization/domain/organization_membership_models.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

abstract class OrganizationGateway {
  Future<List<OrganizationSummary>> listOrganizations();
  Future<void> selectOrganization(OrganizationSummary organization);
  Future<String?> readActiveOrganizationId();
  Future<String?> readActiveOrganizationType();
  Future<OrganizationMembershipPreview> lookupMembershipCode(String code);
  Future<OrganizationMembershipRedeemResult> redeemMembershipCode(String code);
  Future<OrganizationSummary> ensureIndividualWorkspace({
    required String displayName,
    required String userId,
  });
}

class OrganizationRepository implements OrganizationGateway {
  OrganizationRepository({
    ApiClient? apiClient,
    TokenStore? tokenStore,
    TenantStore? tenantStore,
  })  : _api = apiClient ?? ApiClient(),
        _tokens = tokenStore ?? createTokenStore(),
        _tenant = tenantStore ?? createTenantStore();

  final ApiClient _api;
  final TokenStore _tokens;
  final TenantStore _tenant;

  @override
  Future<List<OrganizationSummary>> listOrganizations() async {
    final accessToken = await _requireToken();

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
  Future<void> selectOrganization(OrganizationSummary organization) async {
    await _tenant.saveActiveOrganization(
      id: organization.id,
      name: organization.name,
      type: organization.type,
    );
    MarketplaceAccessService.instance.reset();
    await MarketplaceAccessService.instance.refresh(force: true);
  }

  @override
  Future<String?> readActiveOrganizationId() =>
      _tenant.readActiveOrganizationId();

  @override
  Future<String?> readActiveOrganizationType() =>
      _tenant.readActiveOrganizationType();

  @override
  Future<OrganizationMembershipPreview> lookupMembershipCode(String code) async {
    final envelope = await _api.post(
      '/organization-memberships/lookup-code',
      body: {'code': code.trim()},
    );
    final data = envelope['data'];
    if (data is! Map) {
      throw ApiException(
        message: 'Unable to validate organisation code.',
        statusCode: 500,
        code: 'ORG_MEMBERSHIP_LOOKUP_FAILED',
      );
    }
    return OrganizationMembershipPreview.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<OrganizationMembershipRedeemResult> redeemMembershipCode(
    String code,
  ) async {
    final accessToken = await _requireToken();
    final envelope = await _api.post(
      '/organization-memberships/redeem',
      body: {'code': code.trim()},
      accessToken: accessToken,
    );
    final data = envelope['data'];
    if (data is! Map) {
      throw ApiException(
        message: 'Unable to join organisation.',
        statusCode: 500,
        code: 'ORG_MEMBERSHIP_REDEEM_FAILED',
      );
    }
    return OrganizationMembershipRedeemResult.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<OrganizationSummary> ensureIndividualWorkspace({
    required String displayName,
    required String userId,
  }) async {
    final existing = await listOrganizations();
    final individual = existing.where((org) => org.isIndividual).toList();
    if (individual.isNotEmpty) {
      return individual.first;
    }

    final accessToken = await _requireToken();
    final name = _individualWorkspaceName(displayName);
    final slug = _individualSlug(displayName, userId);

    final envelope = await _api.post(
      '/organizations',
      body: {
        'name': name,
        'slug': slug,
        'type': 'individual',
      },
      accessToken: accessToken,
    );

    final data = envelope['data'];
    if (data is Map) {
      final created = OrganizationSummary.fromJson(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (created.id.isNotEmpty) return created;
    }

    final refreshed = await listOrganizations();
    final match = refreshed.where((org) => org.isIndividual).toList();
    if (match.isNotEmpty) return match.first;

    throw ApiException(
      message: 'Could not create your Individual learning space. Try again.',
      statusCode: 500,
      code: 'INDIVIDUAL_WORKSPACE_CREATE_FAILED',
    );
  }

  Future<String> _requireToken() async {
    final accessToken = await _tokens.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw ApiException(
        message: 'Your session expired. Sign in again.',
        statusCode: 401,
        code: 'AUTH_SESSION_MISSING',
      );
    }
    return accessToken;
  }

  String _individualWorkspaceName(String displayName) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'My Learning';
    return "$trimmed's Learning";
  }

  String _individualSlug(String displayName, String userId) {
    final base = displayName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final idPart = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    final suffix = idPart.length >= 8 ? idPart.substring(0, 8) : idPart;
    final stem = base.isEmpty ? 'student' : base;
    final slug = '$stem-$suffix';
    return slug.length > 60 ? slug.substring(0, 60) : slug;
  }
}
