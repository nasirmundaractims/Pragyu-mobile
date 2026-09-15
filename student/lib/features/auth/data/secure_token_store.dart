import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:student_mobile/features/auth/data/token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'pragyu.access_token';
  static const _refreshKey = 'pragyu.refresh_token';
  static const _userKey = 'pragyu.user_json';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
      _storage.write(key: _userKey, value: userJson),
    ]);
  }

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<String?> readUserJson() => _storage.read(key: _userKey);

  @override
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _userKey),
    ]);
  }
}
