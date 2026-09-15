import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:student_mobile/features/organization/data/tenant_store.dart';

class SecureTenantStore implements TenantStore {
  SecureTenantStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _idKey = 'pragyu.active_organization_id';
  static const _nameKey = 'pragyu.active_organization_name';
  static const _typeKey = 'pragyu.active_organization_type';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveActiveOrganization({
    required String id,
    String? name,
    String? type,
  }) async {
    await Future.wait([
      _storage.write(key: _idKey, value: id),
      if (name != null) _storage.write(key: _nameKey, value: name),
      if (type != null) _storage.write(key: _typeKey, value: type),
    ]);
  }

  @override
  Future<String?> readActiveOrganizationId() => _storage.read(key: _idKey);

  @override
  Future<String?> readActiveOrganizationName() => _storage.read(key: _nameKey);

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _idKey),
      _storage.delete(key: _nameKey),
      _storage.delete(key: _typeKey),
    ]);
  }
}
