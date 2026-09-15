import 'dart:convert';

import 'package:student_mobile/core/storage/platform_stores.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/auth/domain/auth_models.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';

class SessionContext {
  const SessionContext({
    required this.accessToken,
    required this.organizationId,
    this.cachedUser,
  });

  final String accessToken;
  final String organizationId;
  final AuthUser? cachedUser;
}

class SessionService {
  SessionService({
    TokenStore? tokenStore,
    TenantStore? tenantStore,
  })  : _tokens = tokenStore ?? createTokenStore(),
        _tenant = tenantStore ?? createTenantStore();

  final TokenStore _tokens;
  final TenantStore _tenant;

  Future<SessionContext?> read() async {
    final access = await _tokens.readAccessToken();
    final orgId = await _tenant.readActiveOrganizationId();
    if (access == null ||
        access.isEmpty ||
        orgId == null ||
        orgId.isEmpty) {
      return null;
    }

    AuthUser? user;
    final raw = await _tokens.readUserJson();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          user = AuthUser.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (_) {
        user = null;
      }
    }

    return SessionContext(
      accessToken: access,
      organizationId: orgId,
      cachedUser: user,
    );
  }
}
