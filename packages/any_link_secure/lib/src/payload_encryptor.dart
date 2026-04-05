import 'dart:convert';
import 'dart:math';
import 'package:any_link/any_link.dart';
import 'crypto/aes256.dart';

/// AES-256-CTR request/response payload encryption interceptor.
///
/// Encrypts the request body before sending and decrypts the response body
/// after receiving. Provides end-to-end encryption beyond TLS.
///
/// Uses AES-256 in CTR mode — a pure-Dart implementation with no third-party
/// dependencies. The key must be exactly 32 bytes. A random 16-byte nonce is
/// generated per request and included in the payload.
///
/// For healthcare, fintech, and any app requiring confidentiality beyond HTTPS.
///
/// ```dart
/// final key = base64.decode(preSharedBase64Key); // 32 bytes
/// client.interceptors.add(PayloadEncryptor(key: key));
/// ```
class PayloadEncryptor extends AnyLinkInterceptor {
  /// 32-byte AES-256 key.
  final List<int> key;

  PayloadEncryptor({required this.key}) {
    assert(key.length == 32, 'PayloadEncryptor key must be exactly 32 bytes');
  }

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    final body = request.body;
    if (body == null) return request;

    String plaintext;
    if (body is Map || body is List) {
      plaintext = jsonEncode(body);
    } else if (body is String) {
      plaintext = body;
    } else {
      return request;
    }

    final nonce = _generateNonce(); // 16 bytes
    final encrypted = Aes256Ctr.ctr(utf8.encode(plaintext), key, nonce);
    final payload = {
      'nonce': base64.encode(nonce),
      'data': base64.encode(encrypted),
    };

    return request.copyWith(
      body: payload,
      headers: {...?request.headers, 'X-Encrypted': '1'},
    );
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    if (response.headers['x-encrypted'] != '1') return response;

    try {
      final json = response.jsonMap;
      final nonce = base64.decode(json['nonce'] as String);
      final data = base64.decode(json['data'] as String);
      final decrypted = Aes256Ctr.ctr(data, key, nonce);
      return AnyLinkResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        bodyBytes: decrypted,
        requestPath: response.requestPath,
        requestMethod: response.requestMethod,
        durationMs: response.durationMs,
        timestamp: response.timestamp,
      );
    } catch (_) {
      return response;
    }
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  List<int> _generateNonce() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256));
  }
}
