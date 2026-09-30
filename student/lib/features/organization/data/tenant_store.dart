abstract class TenantStore {
  Future<void> saveActiveOrganization({
    required String id,
    String? name,
    String? type,
  });

  Future<String?> readActiveOrganizationId();
  Future<String?> readActiveOrganizationName();
  Future<String?> readActiveOrganizationType();
  Future<void> clear();
}
