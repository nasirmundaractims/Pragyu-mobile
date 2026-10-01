import 'package:student_mobile/features/organization/data/organization_repository.dart';
import 'package:student_mobile/features/organization/domain/organization_membership_models.dart';
import 'package:student_mobile/features/organization/domain/organization_summary.dart';

/// Shared fake for widget tests that touch [OrganizationGateway].
class FakeOrganizationGateway implements OrganizationGateway {
  FakeOrganizationGateway({
    this.organizations = const [],
    this.listError,
    this.activeOrganizationId,
  });

  List<OrganizationSummary> organizations;
  Object? listError;
  OrganizationSummary? selected;
  String? activeOrganizationId;

  @override
  Future<List<OrganizationSummary>> listOrganizations({
    bool learnerWorkspaceOnly = true,
  }) async {
    final error = listError;
    if (error != null) throw error;
    return organizations;
  }

  @override
  Future<void> selectOrganization(OrganizationSummary organization) async {
    selected = organization;
    activeOrganizationId = organization.id;
  }

  @override
  Future<String?> readActiveOrganizationId() async => activeOrganizationId;

  @override
  Future<String?> readActiveOrganizationType() async => selected?.type;

  @override
  Future<OrganizationMembershipPreview> lookupMembershipCode(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<OrganizationMembershipRedeemResult> redeemMembershipCode(
    String code,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<OrganizationSummary> ensureIndividualWorkspace({
    required String displayName,
    required String userId,
  }) async {
    final existing = organizations.where((o) => o.isIndividual).toList();
    if (existing.isNotEmpty) return existing.first;
    const created = OrganizationSummary(
      id: 'individual-1',
      name: 'My Learning',
      type: 'individual',
    );
    organizations = [...organizations, created];
    return created;
  }
}
