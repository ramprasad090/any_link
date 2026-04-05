import 'dart:convert';

/// The response returned by [AnyLinkClient] after a successful HTTP round-trip.
///
/// Body decoding is lazy — [bodyString] and [json] are only computed on first
/// access, so you pay zero cost for responses you only inspect by status code.
class AnyLinkResponse {
  /// HTTP status code.
  final int statusCode;

  /// All response headers, keys lower-cased.
  final Map<String, String> headers;

  /// Raw response body as bytes.
  final List<int> bodyBytes;

  /// Path of the originating request.
  final String requestPath;

  /// Method of the originating request.
  final String requestMethod;

  /// Round-trip time in milliseconds.
  final int durationMs;

  /// Wall-clock time when the response was received.
  final DateTime timestamp;

  AnyLinkResponse({
    required this.statusCode,
    required this.headers,
    required this.bodyBytes,
    required this.requestPath,
    required this.requestMethod,
    required this.durationMs,
    required this.timestamp,
  });

  // ── Lazy decoded body ──────────────────────────────────────────────────────

  late final String bodyString = utf8.decode(bodyBytes, allowMalformed: true);
  late final dynamic json = _tryDecodeJson(bodyString);

  static dynamic _tryDecodeJson(String s) {
    if (s.isEmpty) return null;
    try {
      return jsonDecode(s);
    } on FormatException {
      return null;
    }
  }

  /// Response body decoded as a JSON object.
  Map<String, dynamic> get jsonMap => (json as Map).cast<String, dynamic>();

  /// Response body decoded as a JSON array.
  List<dynamic> get jsonList => json as List<dynamic>;

  /// Response body decoded as a JSON object, or null if not a JSON object.
  Map<String, dynamic>? get jsonMapOrNull =>
      json is Map ? (json as Map).cast<String, dynamic>() : null;

  /// Response body decoded as a JSON array, or null if not a JSON array.
  List<dynamic>? get jsonListOrNull => json is List ? json as List<dynamic> : null;

  // ── Status helpers ─────────────────────────────────────────────────────────

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isRedirect => statusCode >= 300 && statusCode < 400;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  // ── Common headers ─────────────────────────────────────────────────────────

  String? get contentType => headers['content-type'];
  int? get contentLength => int.tryParse(headers['content-length'] ?? '');
  String? get etag => headers['etag'];
  String? get lastModified => headers['last-modified'];

  /// Parses the `Retry-After` header (seconds integer or HTTP-date).
  Duration? get retryAfter {
    final v = headers['retry-after'];
    if (v == null) return null;
    final secs = int.tryParse(v);
    if (secs != null) return Duration(seconds: secs);
    return null;
  }

  /// Value of the `X-Api-Version` response header.
  String? get apiVersion => headers['x-api-version'];

  /// Value of the `Sunset` header — the date this API version will be removed.
  String? get sunsetDate => headers['sunset'];

  /// Value of the `Deprecation` header.
  String? get deprecation => headers['deprecation'];

  @override
  String toString() =>
      'AnyLinkResponse($statusCode $requestMethod $requestPath, ${durationMs}ms, ${bodyBytes.length}B)';
}
