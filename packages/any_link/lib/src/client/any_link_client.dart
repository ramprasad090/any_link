import 'dart:async';

import '../interceptors/base_interceptor.dart';
import '../interceptors/dedup_interceptor.dart';
import '../models/cancel_token.dart';
import '../models/config.dart';
import '../models/error.dart';
import '../models/request.dart';
import '../models/response.dart';
import 'transport/transport_stub.dart'
    if (dart.library.io) 'transport/transport_io.dart'
    if (dart.library.html) 'transport/transport_web.dart';

/// The main HTTP client for `any_link`.
///
/// Works on all platforms: Android, iOS, macOS, Windows, Linux, and Flutter Web.
/// Uses `dart:io` HttpClient on native platforms and XHR on web.
/// No `dio`, no `http` package — zero third-party dependencies.
///
/// ## Quick start
/// ```dart
/// final client = AnyLinkClient(
///   config: AnyLinkConfig(baseUrl: 'https://api.example.com'),
/// );
///
/// final res = await client.get('/users');
/// print(res.jsonList);
/// ```
class AnyLinkClient {
  final AnyLinkConfig config;
  final List<AnyLinkInterceptor> interceptors;

  late final AnyLinkTransport _transport;

  AnyLinkClient({
    required this.config,
    List<AnyLinkInterceptor>? interceptors,
  }) : interceptors = interceptors ?? [] {
    _transport = createTransport(config);
  }

  // ── Public convenience methods ─────────────────────────────────────────────

  Future<AnyLinkResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
    Duration? timeout,
    RequestPriority priority = RequestPriority.normal,
  }) =>
      request(AnyLinkRequest(
        method: 'GET',
        path: path,
        headers: headers,
        queryParams: queryParams,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        timeout: timeout,
        priority: priority,
      ));

  Future<AnyLinkResponse> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    void Function(int, int)? onReceiveProgress,
    Duration? timeout,
    RequestPriority priority = RequestPriority.normal,
    String? idempotencyKey,
  }) =>
      request(AnyLinkRequest(
        method: 'POST',
        path: path,
        body: body,
        headers: headers,
        queryParams: queryParams,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        timeout: timeout,
        priority: priority,
        idempotencyKey: idempotencyKey,
      ));

  Future<AnyLinkResponse> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    Duration? timeout,
  }) =>
      request(AnyLinkRequest(
        method: 'PUT',
        path: path,
        body: body,
        headers: headers,
        queryParams: queryParams,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        timeout: timeout,
      ));

  Future<AnyLinkResponse> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    Duration? timeout,
  }) =>
      request(AnyLinkRequest(
        method: 'PATCH',
        path: path,
        body: body,
        headers: headers,
        queryParams: queryParams,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        timeout: timeout,
      ));

  Future<AnyLinkResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Duration? timeout,
  }) =>
      request(AnyLinkRequest(
        method: 'DELETE',
        path: path,
        headers: headers,
        queryParams: queryParams,
        cancelToken: cancelToken,
        timeout: timeout,
      ));

  Future<AnyLinkResponse> head(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) =>
      request(AnyLinkRequest(
          method: 'HEAD',
          path: path,
          headers: headers,
          queryParams: queryParams));

  Future<AnyLinkResponse> options(
    String path, {
    Map<String, String>? headers,
  }) =>
      request(AnyLinkRequest(
          method: 'OPTIONS', path: path, headers: headers));

  // ── Core request execution ─────────────────────────────────────────────────

  /// Executes a raw [AnyLinkRequest] through the full interceptor chain.
  Future<AnyLinkResponse> request(AnyLinkRequest req) async {
    final dedupInterceptor =
        interceptors.whereType<DeduplicationInterceptor>().firstOrNull;
    if (config.enableDeduplication && dedupInterceptor != null) {
      final inflight = dedupInterceptor.getInflight(req.method, req.path);
      if (inflight != null) return inflight;
    }

    final future = _executeRequest(req);

    if (config.enableDeduplication && dedupInterceptor != null) {
      dedupInterceptor.register(req.method, req.path, future);
    }

    return future;
  }

  Future<AnyLinkResponse> _executeRequest(AnyLinkRequest req) async {
    // 1. Run onRequest interceptors.
    AnyLinkRequest modifiedReq = req;
    for (final interceptor in interceptors) {
      modifiedReq = await interceptor.onRequest(modifiedReq);
    }

    // 2. Check cancel token before connecting.
    if (modifiedReq.cancelToken?.isCancelled ?? false) {
      throw CancelledException(modifiedReq.cancelToken?.reason);
    }

    // 3. Build URI.
    final url = config.resolveUrl(modifiedReq.path);
    final uri = _buildUri(url, modifiedReq.queryParams);

    // 4. Execute the HTTP call via platform transport.
    try {
      final response = await _transport.send(modifiedReq, uri);

      // 5. Run onResponse interceptors.
      AnyLinkResponse modifiedResponse = response;
      for (final interceptor in interceptors.reversed) {
        modifiedResponse = await interceptor.onResponse(modifiedResponse);
      }

      // 6. Throw if error status.
      if (modifiedResponse.statusCode >= 400) {
        final error = AnyLinkError.fromResponse(modifiedResponse,
            mapper: config.errorMapper);
        return _handleError(error, modifiedReq);
      }

      return modifiedResponse;
    } on AnyLinkError {
      rethrow;
    } on CancelledException {
      final error = AnyLinkError(
        message: 'Request cancelled',
        requestPath: modifiedReq.path,
        requestMethod: modifiedReq.method,
        rawError: CancelledException(modifiedReq.cancelToken?.reason),
      );
      return _handleError(error, modifiedReq);
    } on TimeoutException catch (e) {
      final error = AnyLinkError(
        message: 'Request timed out',
        requestPath: modifiedReq.path,
        requestMethod: modifiedReq.method,
        rawError: e,
      );
      return _handleError(error, modifiedReq);
    } catch (e) {
      final error = AnyLinkError(
        message: e.toString(),
        requestPath: modifiedReq.path,
        requestMethod: modifiedReq.method,
        rawError: e,
      );
      return _handleError(error, modifiedReq);
    }
  }

  Future<AnyLinkResponse> _handleError(
      AnyLinkError error, AnyLinkRequest req) async {
    AnyLinkError modifiedError = error;
    for (final interceptor in interceptors.reversed) {
      modifiedError = await interceptor.onError(modifiedError);
      if (modifiedError.resolved && modifiedError.resolvedResponse != null) {
        return modifiedError.resolvedResponse!;
      }
    }
    throw modifiedError;
  }

  Uri _buildUri(String url, Map<String, dynamic>? queryParams) {
    final base = Uri.parse(url);
    if (queryParams == null || queryParams.isEmpty) return base;
    final existing = Map<String, dynamic>.from(base.queryParameters);
    queryParams.forEach((k, v) => existing[k] = v.toString());
    return base.replace(queryParameters: existing);
  }

  /// Close the underlying transport and all persistent connections.
  void close({bool force = false}) => _transport.close(force: force);
}
