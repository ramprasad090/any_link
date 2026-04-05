import 'dart:async';
import 'cancel_token.dart';
import 'response.dart';

/// Represents any failure that occurs during an [AnyLinkClient] operation.
///
/// Covers HTTP errors (4xx / 5xx), network failures, timeouts, and cancellations.
/// Use the boolean helpers to branch without inspecting status codes manually.
///
/// ```dart
/// on AnyLinkError catch (e) {
///   if (e.isValidationError) showFieldErrors(e.validationErrors!);
///   if (e.isUnauthorized) navigateToLogin();
/// }
/// ```
class AnyLinkError implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// HTTP status code, or null for network/timeout/cancel errors.
  final int? statusCode;

  /// Path of the originating request.
  final String? requestPath;

  /// Method of the originating request.
  final String? requestMethod;

  /// Round-trip time in ms (if the request reached the server before failing).
  final int? durationMs;

  /// The raw response, if the server replied with an error status.
  final AnyLinkResponse? response;

  /// Field-level validation errors extracted by an [ErrorMapper].
  /// Keys are field names; values are lists of error messages.
  final Map<String, List<String>>? validationErrors;

  /// Backend-specific error code string (e.g. `"EMAIL_TAKEN"`).
  final String? errorCode;

  /// The underlying exception: [TimeoutException], [CancelledException], or a
  /// raw `dart:io` socket error.
  final dynamic rawError;

  /// Set to `true` by an interceptor that handled the error (e.g. after a
  /// successful token refresh + retry).
  final bool resolved;

  /// The replacement response when [resolved] is `true`.
  final AnyLinkResponse? resolvedResponse;

  /// Arbitrary metadata attached by interceptors (e.g. `{'_retried': true}`).
  final Map<String, dynamic>? extra;

  const AnyLinkError({
    required this.message,
    this.statusCode,
    this.requestPath,
    this.requestMethod,
    this.durationMs,
    this.response,
    this.validationErrors,
    this.errorCode,
    this.rawError,
    this.resolved = false,
    this.resolvedResponse,
    this.extra,
  });

  // ── Convenience booleans ───────────────────────────────────────────────────

  bool get isValidationError => validationErrors?.isNotEmpty ?? false;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => (statusCode ?? 0) >= 500;
  bool get isNetworkError => statusCode == null && rawError is! TimeoutException && rawError is! CancelledException;
  bool get isTimeout => rawError is TimeoutException;
  bool get isCancelled => rawError is CancelledException;

  // ── Field error helpers ────────────────────────────────────────────────────

  /// Returns the first validation error for [field], or null.
  String? fieldError(String field) => validationErrors?[field]?.first;

  /// Returns all validation errors for [field], or null.
  List<String>? fieldErrors(String field) => validationErrors?[field];

  // ── Factory ────────────────────────────────────────────────────────────────

  /// Build an [AnyLinkError] from a server response, optionally using a custom
  /// [mapper] to extract structured validation errors and error codes.
  factory AnyLinkError.fromResponse(
    AnyLinkResponse response, {
    AnyLinkErrorMapper? mapper,
  }) {
    if (mapper != null) return mapper(response);
    return AnyLinkError(
      message: 'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
      requestPath: response.requestPath,
      requestMethod: response.requestMethod,
      durationMs: response.durationMs,
      response: response,
    );
  }

  /// Returns a copy with the given fields overridden.
  AnyLinkError copyWith({
    bool? resolved,
    AnyLinkResponse? resolvedResponse,
    String? message,
    Map<String, List<String>>? validationErrors,
    Map<String, dynamic>? extra,
  }) {
    return AnyLinkError(
      message: message ?? this.message,
      statusCode: statusCode,
      requestPath: requestPath,
      requestMethod: requestMethod,
      durationMs: durationMs,
      response: response,
      validationErrors: validationErrors ?? this.validationErrors,
      errorCode: errorCode,
      rawError: rawError,
      resolved: resolved ?? this.resolved,
      resolvedResponse: resolvedResponse ?? this.resolvedResponse,
      extra: extra ?? this.extra,
    );
  }

  @override
  String toString() => 'AnyLinkError(${statusCode ?? "network"}: $message)';
}

/// Signature for a function that converts a raw [AnyLinkResponse] into a
/// structured [AnyLinkError], extracting validation errors, error codes, etc.
typedef AnyLinkErrorMapper = AnyLinkError Function(AnyLinkResponse response);
