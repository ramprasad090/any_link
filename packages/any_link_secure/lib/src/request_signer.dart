import 'dart:convert';
import 'package:any_link/any_link.dart';
import 'crypto/sha256.dart';

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

  String _hmacSha256(String message, String key) {
    final mac = Sha256.hmac(utf8.encode(key), utf8.encode(message));
    return base64.encode(mac);
  }
}
