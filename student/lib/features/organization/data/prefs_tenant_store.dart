import 'package:shared_preferences/shared_preferences.dart';

import 'package:student_mobile/features/organization/data/tenant_store.dart';

/// Web-safe active-organization persistence.
class PrefsTenantStore implements TenantStore {
  PrefsTenantStore({SharedPreferences? preferences}) : _prefs = preferences;

  static const _idKey = 'pragyu.active_organization_id';
  static const _nameKey = 'pragyu.active_organization_name';
  static const _typeKey = 'pragyu.active_organization_type';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _store() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> saveActiveOrganization({
    required String id,
    String? name,
    String? type,
  }) async {
    final prefs = await _store();
    await prefs.setString(_idKey, id);
    if (name != null) {
      await prefs.setString(_nameKey, name);
    }
    if (type != null) {
      await prefs.setString(_typeKey, type);
    }
  }

  @override
  Future<String?> readActiveOrganizationId() async {
    final prefs = await _store();
    return prefs.getString(_idKey);
  }

  @override
  Future<String?> readActiveOrganizationName() async {
    final prefs = await _store();
    return prefs.getString(_nameKey);
  }

  @override
  Future<void> clear() async {
    final prefs = await _store();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_typeKey);
  }
}
