import 'package:shared_preferences/shared_preferences.dart';

import 'package:student_mobile/features/auth/data/token_store.dart';

/// Web-safe session persistence (SharedPreferences / localStorage).
///
/// `flutter_secure_storage` on Chrome races AES key init when writing
/// multiple keys in parallel, which can make later reads return null.
class PrefsTokenStore implements TokenStore {
  PrefsTokenStore({SharedPreferences? preferences}) : _prefs = preferences;

  static const _accessKey = 'pragyu.access_token';
  static const _refreshKey = 'pragyu.refresh_token';
  static const _userKey = 'pragyu.user_json';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _store() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    final prefs = await _store();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
    await prefs.setString(_userKey, userJson);
  }

  @override
  Future<String?> readAccessToken() async {
    final prefs = await _store();
    return prefs.getString(_accessKey);
  }

  @override
  Future<String?> readRefreshToken() async {
    final prefs = await _store();
    return prefs.getString(_refreshKey);
  }

  @override
  Future<String?> readUserJson() async {
    final prefs = await _store();
    return prefs.getString(_userKey);
  }

  @override
  Future<void> clear() async {
    final prefs = await _store();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userKey);
  }
}
