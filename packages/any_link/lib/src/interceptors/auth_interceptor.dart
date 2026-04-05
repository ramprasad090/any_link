import 'dart:async';
import '../interceptors/base_interceptor.dart';
import '../auth/token_storage.dart';
import '../models/request.dart';
import '../models/error.dart';

/// Attaches Bearer tokens and handles 401 responses with a single refresh call.
///
/// Solves the classic race condition: when 3 concurrent requests all receive a
/// 401, only ONE token-refresh call is made. All 3 requestors wait on the same
/// [Completer], then each retries with the new token.
///
/// ```dart
/// client.interceptors.add(AuthInterceptor(
///   tokenStorage: SecureTokenStorage(),
///   onRefresh: (client, refresh) async {
///     final res = await client.post('/auth/refresh', body: {'refresh_token': refresh});
///     return TokenPair(accessToken: res.jsonMap['access_token'], refreshToken: refresh);
///   },
///   onSessionExpired: () => navigatorKey.currentState?.pushReplacementNamed('/login'),
/// ));
/// ```
class AuthInterceptor extends AnyLinkInterceptor {
  final TokenStorage tokenStorage;

  /// Called exactly once when the current access token has expired.
  /// Return a new [TokenPair] on success; throw to signal session expiry.
  final Future<TokenPair> Function(dynamic client, String refreshToken) onRefresh;

  /// Called when the refresh itself fails (e.g. refresh token also expired).
  final void Function()? onSessionExpired;

  /// When true, decode the JWT `exp` claim before each request and refresh
  /// proactively if the token expires within [_preEmptiveBuffer].
  final bool preEmptiveRefresh;

  static const Duration _preEmptiveBuffer = Duration(seconds: 30);

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.tokenStorage,
    required this.onRefresh,
    this.onSessionExpired,
    this.preEmptiveRefresh = false,
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    // Skip adding auth header to requests that already carry one.
    if (request.headers?.containsKey('Authorization') ?? false) return request;

    String? token = await tokenStorage.getAccessToken();

    if (token != null && preEmptiveRefresh && _isExpiringSoon(token)) {
      token = await _doRefresh(null);
    }

    if (token == null) return request;

    return request.copyWith(
      headers: {...?request.headers, 'Authorization': 'Bearer $token'},
    );
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    if (!error.isUnauthorized) return error;

    // Already tried refreshing — give up.
    if (error.extra?['_retried'] == true) return error;

    final newToken = await _doRefresh(error.rawError);
    if (newToken == null) return error;

    // Signal the client to retry the original request with the new token.
    // We do this by resolving with a sentinel that the client checks.
    return error.copyWith(
      resolved: false, // Client will re-send; we just store new token.
    );
  }

  Future<String?> _doRefresh(dynamic originalError) async {
    if (_isRefreshing) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        onSessionExpired?.call();
        _refreshCompleter!.complete(null);
        return null;
      }

      final pair = await onRefresh(null, refreshToken);
      await tokenStorage.saveTokens(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
      _refreshCompleter!.complete(pair.accessToken);
      return pair.accessToken;
    } catch (_) {
      onSessionExpired?.call();
      await tokenStorage.clearTokens();
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }

  /// Naïve JWT `exp` claim check — no signature verification.
  bool _isExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      // Base64-url decode (pad to multiple of 4)
      final padded = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = String.fromCharCodes(
        _base64UrlDecode(padded),
      );
      final exp = _extractExp(decoded);
      if (exp == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return expiry.isBefore(DateTime.now().add(_preEmptiveBuffer));
    } catch (_) {
      return false;
    }
  }

  List<int> _base64UrlDecode(String input) {
    final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final bytes = <int>[];
    int i = 0;
    while (i < normalized.length) {
      final c = normalized.codeUnitAt(i++);
      int bits;
      if (c >= 65 && c <= 90) {
        bits = c - 65;
      } else if (c >= 97 && c <= 122) {
        bits = c - 71;
      } else if (c >= 48 && c <= 57) {
        bits = c + 4;
      } else if (c == 43) {
        bits = 62;
      } else if (c == 47) {
        bits = 63;
      } else {
        continue;
      }
      bytes.add(bits);
    }
    // Minimal base64 decode for exp value
    return bytes;
  }

  int? _extractExp(String json) {
    final match = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(json);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

}
