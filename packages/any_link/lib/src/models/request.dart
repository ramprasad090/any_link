import 'cancel_token.dart';

/// Priority levels for requests. Higher-priority requests are dispatched first
/// when the connection pool is saturated.
enum RequestPriority {
  /// Authentication and critical session operations. Always run immediately.
  critical,

  /// User-initiated actions (button taps, form submits).
  high,

  /// Default level for data fetches triggered by screen navigation.
  normal,

  /// Prefetch / speculative loads.
  low,

  /// Analytics pings, telemetry, background sync.
  background,
}

/// An immutable description of a single HTTP request.
///
/// Build one directly or let [AnyLinkClient] construct it from the convenience
/// methods ([get], [post], etc.).
class AnyLinkRequest {
  /// HTTP method, upper-cased: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS.
  final String method;

  /// Path relative to [AnyLinkConfig.baseUrl], or a fully-qualified URL.
  final String path;

  /// Headers merged on top of [AnyLinkConfig.defaultHeaders].
  final Map<String, String>? headers;

  /// Query parameters appended to the URL.
  final Map<String, dynamic>? queryParams;

  /// Request body. Accepted types:
  /// - `String` — written as-is
  /// - `Map` / `List` — JSON-encoded automatically
  /// - `List<int>` — written as raw bytes
  /// - `Stream<List<int>>` — streamed without buffering
  /// - `AnyLinkFormData` — multipart form, streamed from disk
  final dynamic body;

  /// Called periodically while the request body is being sent.
  /// [sent] and [total] are in bytes; [total] may be -1 when unknown.
  final void Function(int sent, int total)? onSendProgress;

  /// Called periodically while the response body is being received.
  final void Function(int received, int total)? onReceiveProgress;

  /// Optional token to abort this request mid-flight.
  final CancelToken? cancelToken;

  /// Per-request timeout, overrides [AnyLinkConfig.receiveTimeout].
  final Duration? timeout;

  /// Controls dispatch order under load.
  final RequestPriority priority;

  /// Idempotency key attached as `Idempotency-Key` header.
  /// Auto-generated when [AnyLinkConfig.enableIdempotencyKeys] is true.
  final String? idempotencyKey;

  /// Arbitrary data passed through the interceptor chain unchanged.
  final Map<String, dynamic>? extra;

  const AnyLinkRequest({
    required this.method,
    required this.path,
    this.headers,
    this.queryParams,
    this.body,
    this.onSendProgress,
    this.onReceiveProgress,
    this.cancelToken,
    this.timeout,
    this.priority = RequestPriority.normal,
    this.idempotencyKey,
    this.extra,
  });

  /// Returns a copy with the given fields overridden.
  AnyLinkRequest copyWith({
    String? method,
    String? path,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    dynamic body,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    CancelToken? cancelToken,
    Duration? timeout,
    RequestPriority? priority,
    String? idempotencyKey,
    Map<String, dynamic>? extra,
  }) {
    return AnyLinkRequest(
      method: method ?? this.method,
      path: path ?? this.path,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      body: body ?? this.body,
      onSendProgress: onSendProgress ?? this.onSendProgress,
      onReceiveProgress: onReceiveProgress ?? this.onReceiveProgress,
      cancelToken: cancelToken ?? this.cancelToken,
      timeout: timeout ?? this.timeout,
      priority: priority ?? this.priority,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      extra: extra ?? this.extra,
    );
  }

  @override
  String toString() => '$method $path';
}
