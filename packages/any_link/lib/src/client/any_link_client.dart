import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../form_data/any_link_form_data.dart';
import '../interceptors/base_interceptor.dart';
import '../interceptors/dedup_interceptor.dart';
import '../models/cancel_token.dart';
import '../models/config.dart';
import '../models/error.dart';
import '../models/request.dart';
import '../models/response.dart';

/// The main HTTP client for `any_link`.
///
/// Built directly on `dart:io` [HttpClient] — no `dio`, no `http` package.
/// Controls every socket, every progress callback, every timeout.
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

  late final HttpClient _nativeClient;

  AnyLinkClient({
    required this.config,
    List<AnyLinkInterceptor>? interceptors,
  }) : interceptors = interceptors ?? [] {
    _nativeClient = HttpClient()
      ..connectionTimeout = config.connectTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost
      ..autoUncompress = true;
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
      request(AnyLinkRequest(method: 'HEAD', path: path, headers: headers, queryParams: queryParams));

  Future<AnyLinkResponse> options(
    String path, {
    Map<String, String>? headers,
  }) =>
      request(AnyLinkRequest(method: 'OPTIONS', path: path, headers: headers));

  // ── Core request execution ─────────────────────────────────────────────────

  /// Executes a raw [AnyLinkRequest] through the full interceptor chain.
  Future<AnyLinkResponse> request(AnyLinkRequest req) async {
    // Deduplication check.
    final dedupInterceptor = interceptors.whereType<DeduplicationInterceptor>().firstOrNull;
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

    // 4. Execute the HTTP call.
    try {
      final response = await _sendRequest(modifiedReq, uri);

      // 5. Run onResponse interceptors.
      AnyLinkResponse modifiedResponse = response;
      for (final interceptor in interceptors.reversed) {
        modifiedResponse = await interceptor.onResponse(modifiedResponse);
      }

      // 6. Throw if error status.
      if (modifiedResponse.statusCode >= 400) {
        final error = AnyLinkError.fromResponse(modifiedResponse, mapper: config.errorMapper);
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

  Future<AnyLinkResponse> _handleError(AnyLinkError error, AnyLinkRequest req) async {
    AnyLinkError modifiedError = error;
    for (final interceptor in interceptors.reversed) {
      modifiedError = await interceptor.onError(modifiedError);
      if (modifiedError.resolved && modifiedError.resolvedResponse != null) {
        return modifiedError.resolvedResponse!;
      }
    }
    throw modifiedError;
  }

  Future<AnyLinkResponse> _sendRequest(AnyLinkRequest req, Uri uri) async {
    final stopwatch = Stopwatch()..start();

    final httpReq = await _nativeClient
        .openUrl(req.method, uri)
        .timeout(config.connectTimeout);

    // Set headers.
    // Note: Accept-Encoding is intentionally omitted — dart:io sets it
    // automatically and handles decompression via autoUncompress = true.
    // Manually setting it bypasses dart:io's decompression pipeline.
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      ...config.defaultHeaders,
      ...?req.headers,
    };

    mergedHeaders.forEach((k, v) => httpReq.headers.set(k, v));

    // Write body.
    await _writeBody(httpReq, req);

    // Get response, honouring cancel token.
    final cancelToken = req.cancelToken;
    HttpClientResponse httpRes;

    if (cancelToken != null) {
      final responseFuture = httpReq.close();
      httpRes = await Future.any([
        responseFuture,
        cancelToken.whenCancelled.then((_) {
          httpReq.abort();
          throw CancelledException(cancelToken.reason);
        }),
      ]).timeout(req.timeout ?? config.receiveTimeout);
    } else {
      httpRes = await httpReq.close().timeout(req.timeout ?? config.receiveTimeout);
    }

    // Read body with optional progress.
    final bytes = await _readBody(httpRes, req.onReceiveProgress, cancelToken);

    stopwatch.stop();

    // Build headers map (lower-cased keys).
    final headers = <String, String>{};
    httpRes.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });

    return AnyLinkResponse(
      statusCode: httpRes.statusCode,
      headers: headers,
      bodyBytes: bytes,
      requestPath: req.path,
      requestMethod: req.method,
      durationMs: stopwatch.elapsedMilliseconds,
      timestamp: DateTime.now(),
    );
  }

  Future<void> _writeBody(HttpClientRequest httpReq, AnyLinkRequest req) async {
    final body = req.body;
    if (body == null) return;

    if (body is AnyLinkFormData) {
      httpReq.headers.set('Content-Type', body.contentTypeHeader);
      final total = await body.totalBytes;
      int sent = 0;
      await for (final chunk in body.toStream()) {
        httpReq.add(chunk);
        sent += chunk.length;
        req.onSendProgress?.call(sent, total);
      }
    } else if (body is String) {
      httpReq.headers.contentType = ContentType.text;
      final bytes = utf8.encode(body);
      httpReq.add(bytes);
      req.onSendProgress?.call(bytes.length, bytes.length);
    } else if (body is Map || body is List) {
      httpReq.headers.contentType = ContentType.json;
      final bytes = utf8.encode(jsonEncode(body));
      httpReq.add(bytes);
      req.onSendProgress?.call(bytes.length, bytes.length);
    } else if (body is List<int>) {
      httpReq.add(body);
      req.onSendProgress?.call(body.length, body.length);
    } else if (body is Stream<List<int>>) {
      int sent = 0;
      await for (final chunk in body) {
        httpReq.add(chunk);
        sent += chunk.length;
        req.onSendProgress?.call(sent, -1);
      }
    }
  }

  Future<List<int>> _readBody(
    HttpClientResponse response,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  ) async {
    final total = response.contentLength;
    int received = 0;
    final chunks = <List<int>>[];

    await for (final chunk in response) {
      if (cancelToken?.isCancelled ?? false) {
        throw CancelledException(cancelToken?.reason);
      }
      chunks.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }

    return chunks.expand((c) => c).toList();
  }

  Uri _buildUri(String url, Map<String, dynamic>? queryParams) {
    final base = Uri.parse(url);
    if (queryParams == null || queryParams.isEmpty) return base;

    final existing = Map<String, dynamic>.from(base.queryParameters);
    queryParams.forEach((k, v) => existing[k] = v.toString());
    return base.replace(queryParameters: existing);
  }

  /// Close the underlying HTTP client and all persistent connections.
  void close({bool force = false}) => _nativeClient.close(force: force);
}
