import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:student_mobile/features/auth/data/prefs_token_store.dart';
import 'package:student_mobile/features/auth/data/secure_token_store.dart';
import 'package:student_mobile/features/auth/data/token_store.dart';
import 'package:student_mobile/features/organization/data/prefs_tenant_store.dart';
import 'package:student_mobile/features/organization/data/secure_tenant_store.dart';
import 'package:student_mobile/features/organization/data/tenant_store.dart';

/// Default stores: SharedPreferences on web, secure storage on mobile.
TokenStore createTokenStore() =>
    kIsWeb ? PrefsTokenStore() : SecureTokenStore();

TenantStore createTenantStore() =>
    kIsWeb ? PrefsTenantStore() : SecureTenantStore();
