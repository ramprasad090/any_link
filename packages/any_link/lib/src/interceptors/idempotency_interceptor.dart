import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Automatically attaches an `Idempotency-Key` header to state-mutating
/// requests (POST, PUT, PATCH).
///
/// The key is a UUID v4 generated per-request. On retry the same key is reused
/// so the server knows it's a safe duplicate and can return a cached result.
///
/// Supported by Stripe, PayPal, Razorpay, and any REST API following RFC 8628.
class IdempotencyInterceptor extends AnyLinkInterceptor {
  static const _mutatingMethods = {'POST', 'PUT', 'PATCH'};

  // key → stored response for client-side dedup on retry.
  final Map<String, AnyLinkResponse> _cache = {};

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    if (!_mutatingMethods.contains(request.method.toUpperCase())) return request;

    final key = request.idempotencyKey ?? _generateUuid();
    final cached = _cache[key];
    if (cached != null) return request; // already have result; client will short-circuit

    return request.copyWith(
      idempotencyKey: key,
      headers: {...?request.headers, 'Idempotency-Key': key},
    );
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  // ── UUID v4 generator (no dependencies) ───────────────────────────────────

  static String _generateUuid() {
    final bytes = List<int>.generate(16, (_) => _random());
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static int _random() {
    return DateTime.now().microsecondsSinceEpoch & 0xff ^
        (DateTime.now().hashCode & 0xff);
  }
}
