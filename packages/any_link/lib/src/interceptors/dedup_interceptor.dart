import 'dart:async';
import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Prevents duplicate simultaneous GET requests from hitting the server.
///
/// When 3 widgets fire `GET /products` at the same time, only 1 HTTP call is
/// made. All 3 callers share the result.
///
/// Only GET requests are deduplicated — mutations must always execute.
class DeduplicationInterceptor extends AnyLinkInterceptor {
  final Map<String, Future<AnyLinkResponse>> _inflight = {};

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async => request;

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    _inflight.remove(_key(response.requestMethod, response.requestPath));
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    _inflight.remove('${error.requestMethod}:${error.requestPath}');
    return error;
  }

  /// Called by [AnyLinkClient] before making the network call.
  /// Returns an existing in-flight future if one exists for this key.
  Future<AnyLinkResponse>? getInflight(String method, String path) {
    if (method.toUpperCase() != 'GET') return null;
    return _inflight[_key(method, path)];
  }

  /// Registers a new in-flight future. Called by [AnyLinkClient].
  void register(String method, String path, Future<AnyLinkResponse> future) {
    if (method.toUpperCase() != 'GET') return;
    _inflight[_key(method, path)] = future;
  }

  String _key(String method, String path) => '$method:$path';
}
