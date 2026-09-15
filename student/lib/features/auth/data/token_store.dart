abstract class TokenStore {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required String userJson,
  });

  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<String?> readUserJson();
  Future<void> clear();
}
