import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../form_data/any_link_form_data.dart';
import '../../models/cancel_token.dart';
import '../../models/config.dart';
import '../../models/request.dart';
import '../../models/response.dart';
import 'transport_stub.dart';

AnyLinkTransport createTransport(AnyLinkConfig config) =>
    IoTransport(config);

class IoTransport implements AnyLinkTransport {
  final AnyLinkConfig config;
  late final HttpClient _client;

  IoTransport(this.config) {
    SecurityContext? ctx;
    if (config.enableHttp2) {
      ctx = SecurityContext(withTrustedRoots: true)
        ..setAlpnProtocols(['h2', 'http/1.1'], false);
    }
    _client = HttpClient(context: ctx)
      ..connectionTimeout = config.connectTimeout
      ..idleTimeout = config.idleTimeout
      ..maxConnectionsPerHost = config.maxConnectionsPerHost
      ..autoUncompress = true;
  }

  @override
  Future<AnyLinkResponse> send(AnyLinkRequest req, Uri uri) async {
    final stopwatch = Stopwatch()..start();

    final httpReq = await _client
        .openUrl(req.method, uri)
        .timeout(config.connectTimeout);

    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      ...config.defaultHeaders,
      ...?req.headers,
    };
    mergedHeaders.forEach((k, v) => httpReq.headers.set(k, v));

    await _writeBody(httpReq, req);

    final cancelToken = req.cancelToken;
    HttpClientResponse httpRes;

    if (cancelToken != null) {
      httpRes = await Future.any([
        httpReq.close(),
        cancelToken.whenCancelled.then((_) {
          httpReq.abort();
          throw CancelledException(cancelToken.reason);
        }),
      ]).timeout(req.timeout ?? config.receiveTimeout);
    } else {
      httpRes =
          await httpReq.close().timeout(req.timeout ?? config.receiveTimeout);
    }

    final bytes = await _readBody(httpRes, req.onReceiveProgress, cancelToken);
    stopwatch.stop();

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

  @override
  void close({bool force = false}) => _client.close(force: force);
}
