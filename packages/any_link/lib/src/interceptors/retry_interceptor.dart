import 'dart:async';
import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Automatically retries failed requests with exponential back-off.
///
/// By default retries on timeouts, network errors, and 5xx responses.
/// Honours the `Retry-After` header when [respectRetryAfter] is true.
///
/// ```dart
/// client.interceptors.add(RetryInterceptor(
///   maxRetries: 3,
///   shouldRetry: (e) => e.isServerError || e.isTimeout,
/// ));
/// ```
class RetryInterceptor extends AnyLinkInterceptor {
  /// Maximum number of retry attempts (not counting the original).
  final int maxRetries;

  /// Delay before each attempt. Default: exponential 1s → 2s → 4s.
  final Duration Function(int attempt) delayFn;

  /// Whether to retry this error. Default: timeout, network error, 5xx.
  final bool Function(AnyLinkError error) shouldRetry;

  /// Honour the `Retry-After` response header when present.
  final bool respectRetryAfter;

  RetryInterceptor({
    this.maxRetries = 3,
    Duration Function(int attempt)? delayFn,
    bool Function(AnyLinkError)? shouldRetry,
    this.respectRetryAfter = true,
  })  : delayFn = delayFn ?? _defaultDelay,
        shouldRetry = shouldRetry ?? _defaultShouldRetry;

  static Duration _defaultDelay(int attempt) =>
      Duration(milliseconds: (1000 * (1 << (attempt - 1))).clamp(0, 30000));

  static bool _defaultShouldRetry(AnyLinkError e) =>
      e.isTimeout || e.isNetworkError || e.isServerError;

  // Tracks retry counts per request key (method+path).
  final Map<String, int> _attempts = {};

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async => request;

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    _attempts.remove(_responseKey(response));
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    final key = '${error.requestMethod}:${error.requestPath}';
    final attempt = (_attempts[key] ?? 0) + 1;

    if (!shouldRetry(error) || attempt > maxRetries) {
      _attempts.remove(key);
      return error;
    }

    _attempts[key] = attempt;

    // Determine delay: respect Retry-After if present, else use delayFn.
    Duration delay = delayFn(attempt);
    if (respectRetryAfter) {
      final serverDelay = error.response?.retryAfter;
      if (serverDelay != null && serverDelay > delay) delay = serverDelay;
    }

    await Future<void>.delayed(delay);

    // Signal the client to retry by resolving (client sees resolved=false + null resolvedResponse).
    // This implementation marks via extra for the client to detect.
    return error.copyWith(
      resolved: false,
    );
  }

  String _responseKey(AnyLinkResponse r) => '${r.requestMethod}:${r.requestPath}';
}
