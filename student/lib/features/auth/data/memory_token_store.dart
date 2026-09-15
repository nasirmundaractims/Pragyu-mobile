import 'package:student_mobile/features/auth/data/token_store.dart';

/// In-memory store for widget/unit tests.
class MemoryTokenStore implements TokenStore {
  String? accessToken;
  String? refreshToken;
  String? userJson;

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.userJson = userJson;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<String?> readUserJson() async => userJson;

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    userJson = null;
  }
}
