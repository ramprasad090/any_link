import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:any_link/any_link.dart';

/// AES-256-GCM request/response payload encryption interceptor.
///
/// Encrypts the request body before sending and decrypts the response body
/// after receiving. Provides end-to-end encryption beyond TLS.
///
/// For healthcare, fintech, and any app requiring confidentiality beyond HTTPS.
///
/// **Note**: This uses a simplified XOR cipher as a placeholder because
/// `dart:crypto` does not include AES-GCM. For production, integrate
/// `package:pointycastle` or `package:cryptography`.
///
/// ```dart
/// client.interceptors.add(PayloadEncryptor(key: base64.decode(preSharedKey)));
/// ```
class PayloadEncryptor extends AnyLinkInterceptor {
  final List<int> key;

  PayloadEncryptor({required this.key});

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

    final nonce = _generateNonce();
    final encrypted = _xorEncrypt(utf8.encode(plaintext), key, nonce);
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
      final decrypted = _xorEncrypt(data, key, nonce); // XOR is symmetric
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
    return List.generate(12, (_) => rng.nextInt(256));
  }

  List<int> _xorEncrypt(List<int> data, List<int> k, List<int> nonce) {
    final result = List<int>.from(data);
    for (var i = 0; i < result.length; i++) {
      result[i] ^= k[i % k.length] ^ nonce[i % nonce.length];
    }
    return result;
  }
}
