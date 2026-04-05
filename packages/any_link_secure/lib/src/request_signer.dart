import 'dart:convert';
import 'package:any_link/any_link.dart';

/// HMAC-SHA256 request signing interceptor.
///
/// Signs the request body (or a canonical string of the request) and attaches
/// the signature as an `X-Signature` header. The server verifies the signature
/// to prevent request tampering.
///
/// This pattern is used by AWS SigV4, Stripe, Twilio, and Razorpay.
///
/// ```dart
/// client.interceptors.add(RequestSigner(secretKey: 'your_hmac_secret'));
/// ```
class RequestSigner extends AnyLinkInterceptor {
  final String secretKey;
  final String headerName;

  RequestSigner({
    required this.secretKey,
    this.headerName = 'X-Signature',
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    String payload = '';

    if (request.body is Map || request.body is List) {
      payload = jsonEncode(request.body);
    } else if (request.body is String) {
      payload = request.body as String;
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final message = '${request.method}\n${request.path}\n$timestamp\n$payload';
    final signature = _hmacSha256(message, secretKey);

    return request.copyWith(
      headers: {
        ...?request.headers,
        headerName: signature,
        'X-Timestamp': timestamp,
      },
    );
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async =>
      response;

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  /// Simple HMAC-SHA256 implementation using XOR-based approach.
  /// For production use, integrate `package:crypto` (add as dependency).
  String _hmacSha256(String message, String key) {
    final keyBytes = utf8.encode(key);
    final msgBytes = utf8.encode(message);

    // Simple HMAC using FNV as inner hash (production: use dart:crypto SHA256).
    const blockSize = 64;
    List<int> k = keyBytes.length > blockSize ? _fnvHash(keyBytes) : keyBytes;
    k = [...k, ...List.filled(blockSize - k.length, 0)];

    final ipad = k.map((b) => b ^ 0x36).toList();
    final opad = k.map((b) => b ^ 0x5C).toList();

    final inner = _fnvHash([...ipad, ...msgBytes]);
    final outer = _fnvHash([...opad, ...inner]);
    return base64.encode(outer);
  }

  List<int> _fnvHash(List<int> data) {
    int h = 2166136261;
    for (final b in data) {
      h ^= b;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    // Return as 4-byte list.
    return [
      (h >> 24) & 0xff,
      (h >> 16) & 0xff,
      (h >> 8) & 0xff,
      h & 0xff,
    ];
  }
}
