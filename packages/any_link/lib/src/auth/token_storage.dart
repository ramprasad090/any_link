/// Pair of access and refresh tokens returned by a token-refresh endpoint.
class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({required this.accessToken, required this.refreshToken});
}

/// Persistent token storage interface.
///
/// Implement with `flutter_secure_storage` for production. Use
/// [InMemoryTokenStorage] for tests.
///
/// ```dart
/// class SecureTokenStorage implements TokenStorage {
///   final _storage = FlutterSecureStorage();
///   @override
///   Future<String?> getAccessToken() => _storage.read(key: 'access_token');
///   // ...
/// }
/// ```
abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();
}

/// In-memory [TokenStorage] — useful for tests and demo apps.
class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
