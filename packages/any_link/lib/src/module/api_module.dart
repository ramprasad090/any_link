import '../client/any_link_client.dart';
import '../models/cancel_token.dart';
import '../models/request.dart';
import '../models/response.dart';

/// Feature-based API organisation. Extend to group related endpoints.
///
/// Each module automatically tags all its requests with [prefix] so they
/// appear labelled in log output.
///
/// ```dart
/// class OrderApi extends ApiModule {
///   OrderApi(AnyLinkClient client) : super(client, prefix: 'OrderAPI');
///
///   Future<Order> createOrder(CreateOrderRequest req) async {
///     final res = await post('/orders', body: req.toJson());
///     return Order.fromJson(res.jsonMap);
///   }
/// }
/// ```
abstract class ApiModule {
  final AnyLinkClient client;
  final String prefix;

  ApiModule(this.client, {required this.prefix});

  Future<AnyLinkResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Duration? timeout,
    RequestPriority priority = RequestPriority.normal,
  }) =>
      client.get(
        path,
        headers: _tagged(headers),
        queryParams: queryParams,
        cancelToken: cancelToken,
        timeout: timeout,
        priority: priority,
      );

  Future<AnyLinkResponse> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
    Duration? timeout,
    RequestPriority priority = RequestPriority.normal,
  }) =>
      client.post(
        path,
        body: body,
        headers: _tagged(headers),
        queryParams: queryParams,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        timeout: timeout,
        priority: priority,
      );

  Future<AnyLinkResponse> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Duration? timeout,
  }) =>
      client.put(
        path,
        body: body,
        headers: _tagged(headers),
        queryParams: queryParams,
        cancelToken: cancelToken,
        timeout: timeout,
      );

  Future<AnyLinkResponse> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Duration? timeout,
  }) =>
      client.patch(
        path,
        body: body,
        headers: _tagged(headers),
        queryParams: queryParams,
        cancelToken: cancelToken,
        timeout: timeout,
      );

  Future<AnyLinkResponse> delete(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    Duration? timeout,
  }) =>
      client.delete(
        path,
        headers: _tagged(headers),
        queryParams: queryParams,
        cancelToken: cancelToken,
        timeout: timeout,
      );

  Map<String, String> _tagged(Map<String, String>? headers) => {
        'X-Module': prefix,
        ...?headers,
      };
}
