import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../form_data/any_link_form_data.dart';
import '../../models/cancel_token.dart';
import '../../models/config.dart';
import '../../models/error.dart';
import '../../models/request.dart';
import '../../models/response.dart';
import 'any_link_transport.dart';

AnyLinkTransport createTransport(AnyLinkConfig config) => WebTransport(config);

class WebTransport implements AnyLinkTransport {
  final AnyLinkConfig config;

  WebTransport(this.config);

  @override
  Future<AnyLinkResponse> send(AnyLinkRequest req, Uri uri) async {
    final stopwatch = Stopwatch()..start();
    final cancelToken = req.cancelToken;

    final xhr = html.HttpRequest();
    xhr.open(req.method, uri.toString());
    xhr.responseType = 'arraybuffer';
    xhr.timeout = (req.timeout ?? config.receiveTimeout).inMilliseconds;

    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      ...config.defaultHeaders,
      ...?req.headers,
    };

    // Build body before setting headers (FormData sets its own Content-Type).
    Object? xhrBody;
    if (req.body != null) {
      if (req.body is AnyLinkFormData) {
        // Stream the multipart body into bytes, then send as Blob.
        final fd = req.body as AnyLinkFormData;
        final chunks = <int>[];
        await for (final chunk in fd.toStream()) {
          chunks.addAll(chunk);
        }
        mergedHeaders['Content-Type'] = fd.contentTypeHeader;
        xhrBody = Uint8List.fromList(chunks);
      } else if (req.body is Map || req.body is List) {
        mergedHeaders['Content-Type'] = 'application/json';
        xhrBody = jsonEncode(req.body);
      } else if (req.body is String) {
        mergedHeaders['Content-Type'] = 'text/plain';
        xhrBody = req.body as String;
      } else if (req.body is List<int>) {
        xhrBody = Uint8List.fromList(req.body as List<int>);
      }
    }

    mergedHeaders.forEach(xhr.setRequestHeader);

    final completer = Completer<AnyLinkResponse>();

    final token = cancelToken;
    if (token != null) {
      token.whenCancelled.then((_) {
        if (!completer.isCompleted) {
          xhr.abort();
          completer.completeError(CancelledException(token.reason));
        }
      });
    }

    xhr.onLoad.listen((_) {
      if (completer.isCompleted) return;
      stopwatch.stop();

      final rawHeaders = xhr.getAllResponseHeaders();
      final headers = <String, String>{};
      for (final line in rawHeaders.trim().split('\r\n')) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          headers[line.substring(0, idx).trim().toLowerCase()] =
              line.substring(idx + 1).trim();
        }
      }

      final buffer = xhr.response as ByteBuffer;
      final bytes = buffer.asUint8List();

      completer.complete(AnyLinkResponse(
        statusCode: xhr.status ?? 0,
        headers: headers,
        bodyBytes: bytes,
        requestPath: req.path,
        requestMethod: req.method,
        durationMs: stopwatch.elapsedMilliseconds,
        timestamp: DateTime.now(),
      ));
    });

    xhr.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(AnyLinkError(
          message: 'Network error',
          requestPath: req.path,
          requestMethod: req.method,
        ));
      }
    });

    xhr.onTimeout.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException(
          'Request timed out',
          req.timeout ?? config.receiveTimeout,
        ));
      }
    });

    xhr.send(xhrBody);
    return completer.future;
  }

  @override
  void close({bool force = false}) {
    // No persistent connections on web.
  }
}
