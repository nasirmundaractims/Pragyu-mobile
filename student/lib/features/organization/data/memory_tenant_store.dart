import 'package:student_mobile/features/organization/data/tenant_store.dart';

class MemoryTenantStore implements TenantStore {
  String? id;
  String? name;
  String? type;

  @override
  Future<void> saveActiveOrganization({
    required String id,
    String? name,
    String? type,
  }) async {
    this.id = id;
    this.name = name;
    this.type = type;
  }

  @override
  Future<String?> readActiveOrganizationId() async => id;

  @override
  Future<String?> readActiveOrganizationName() async => name;

  @override
  Future<void> clear() async {
    id = null;
    name = null;
    type = null;
  }
}
