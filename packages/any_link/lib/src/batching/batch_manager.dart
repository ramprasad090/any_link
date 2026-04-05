import 'dart:convert';
import '../client/any_link_client.dart';
import '../models/error.dart';
import '../models/response.dart';

/// A single request within a [BatchManager.batch] call.
class BatchRequest {
  /// Identifier used to retrieve results from [BatchResponse].
  final String id;
  final String method;
  final String endpoint;
  final dynamic body;
  final Map<String, String>? headers;

  const BatchRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.body,
    this.headers,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': endpoint,
        if (body != null) 'body': body,
        if (headers != null) 'headers': headers,
      };
}

/// The aggregated result of a [BatchManager.batch] call.
class BatchResponse {
  final Map<String, AnyLinkResponse> _results;
  final Map<String, AnyLinkError> _errors;

  const BatchResponse({
    required Map<String, AnyLinkResponse> results,
    required Map<String, AnyLinkError> errors,
  })  : _results = results,
        _errors = errors;

  /// Returns the decoded body for request [id] using [fromJson].
  T get<T>(String id, T Function(Map<String, dynamic>) fromJson) {
    return fromJson(_results[id]!.jsonMap);
  }

  /// Returns the raw [AnyLinkResponse] for request [id].
  AnyLinkResponse getRaw(String id) => _results[id]!;

  /// Whether request [id] resulted in an error.
  bool hasError(String id) => _errors.containsKey(id);

  /// The error for request [id], if any.
  AnyLinkError? getError(String id) => _errors[id];
}

/// Combines multiple requests into a single HTTP call via a batch endpoint.
///
/// The server receives one POST with an array of requests and dispatches them
/// internally, returning an array of responses.
///
/// Falls back to parallel [Future.wait] when a batch endpoint is unavailable.
///
/// ```dart
/// final manager = BatchManager(client: client, batchEndpoint: '/batch');
/// final result = await manager.batch([
///   BatchRequest(id: 'profile', method: 'GET', endpoint: '/user/me'),
///   BatchRequest(id: 'cart',    method: 'GET', endpoint: '/cart'),
/// ]);
/// final user = result.get('profile', User.fromJson);
/// ```
class BatchManager {
  final AnyLinkClient client;
  final String batchEndpoint;

  const BatchManager({
    required this.client,
    this.batchEndpoint = '/batch',
  });

  /// Send all [requests] as a single POST to [batchEndpoint].
  Future<BatchResponse> batch(List<BatchRequest> requests) async {
    final body = requests.map((r) => r.toJson()).toList();
    final response = await client.post(batchEndpoint, body: body);

    final items = response.jsonList;
    final results = <String, AnyLinkResponse>{};
    final errors = <String, AnyLinkError>{};

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'] as String? ?? '';
      final statusCode = item['status'] as int? ?? 200;
      final responseBody = item['body'];
      final bodyBytes = utf8.encode(jsonEncode(responseBody));

      final subResponse = AnyLinkResponse(
        statusCode: statusCode,
        headers: {},
        bodyBytes: bodyBytes,
        requestPath: requests.firstWhere((r) => r.id == id).endpoint,
        requestMethod: requests.firstWhere((r) => r.id == id).method,
        durationMs: 0,
        timestamp: DateTime.now(),
      );

      if (statusCode >= 400) {
        errors[id] = AnyLinkError.fromResponse(subResponse);
      } else {
        results[id] = subResponse;
      }
    }

    return BatchResponse(results: results, errors: errors);
  }

  /// Run all [functions] in parallel and return their results.
  Future<List<AnyLinkResponse>> parallel(
    List<Future<AnyLinkResponse> Function()> functions,
  ) =>
      Future.wait(functions.map((f) => f()));
}
