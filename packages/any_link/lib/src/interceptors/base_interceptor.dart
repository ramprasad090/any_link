import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Base class for all request/response interceptors.
///
/// Interceptors are executed in registration order for requests, and reverse
/// order for responses and errors.
///
/// Override only the hooks you need — the defaults are pass-throughs.
///
/// ```dart
/// class TimestampInterceptor extends AnyLinkInterceptor {
///   @override
///   Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
///     return request.copyWith(
///       headers: {...?request.headers, 'X-Request-Time': DateTime.now().toIso8601String()},
///     );
///   }
/// }
/// ```
abstract class AnyLinkInterceptor {
  /// Called before the request is sent. Return the (possibly modified) request.
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async => request;

  /// Called after a successful response is received. Return the (possibly
  /// modified) response.
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async => response;

  /// Called when any error occurs (network, timeout, HTTP 4xx/5xx, cancel).
  ///
  /// To resolve the error (e.g. after a successful token refresh + retry),
  /// return `error.copyWith(resolved: true, resolvedResponse: retryResponse)`.
  /// The client will then return [AnyLinkError.resolvedResponse] to the caller
  /// instead of throwing.
  Future<AnyLinkError> onError(AnyLinkError error) async => error;
}
