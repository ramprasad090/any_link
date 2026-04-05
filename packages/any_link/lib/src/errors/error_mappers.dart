import 'dart:convert';
import '../models/error.dart';
import '../models/response.dart';

/// Pre-built [AnyLinkErrorMapper] implementations for common backend frameworks.
///
/// Pass one of these to [AnyLinkConfig.errorMapper]:
/// ```dart
/// AnyLinkConfig(
///   baseUrl: 'https://api.example.com',
///   errorMapper: ErrorMappers.laravel,
/// )
/// ```
class ErrorMappers {
  ErrorMappers._();

  // ── Laravel ──────────────────────────────────────────────────────────────
  // {"message": "...", "errors": {"email": ["required", "unique"]}}

  static AnyLinkError laravel(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final message = body['message'] as String? ?? 'HTTP ${r.statusCode}';
      final rawErrors = body['errors'] as Map<String, dynamic>?;
      final validation = rawErrors?.map((k, v) =>
          MapEntry(k, (v as List).map((e) => e.toString()).toList()));
      return AnyLinkError(
        message: message,
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
        validationErrors: validation,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── Django REST Framework ─────────────────────────────────────────────────
  // {"detail": "..."} or {"field": ["error msg"]}

  static AnyLinkError django(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail != null) {
        return AnyLinkError(
          message: detail.toString(),
          statusCode: r.statusCode,
          requestPath: r.requestPath,
          requestMethod: r.requestMethod,
          durationMs: r.durationMs,
          response: r,
        );
      }
      // Field-level errors.
      final validation = <String, List<String>>{};
      for (final entry in body.entries) {
        if (entry.value is List) {
          validation[entry.key] = (entry.value as List).map((e) => e.toString()).toList();
        }
      }
      return AnyLinkError(
        message: 'Validation error',
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
        validationErrors: validation.isEmpty ? null : validation,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── Express / Node ────────────────────────────────────────────────────────
  // {"error": "...", "message": "..."}

  static AnyLinkError express(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final message =
          (body['message'] ?? body['error'] ?? 'HTTP ${r.statusCode}').toString();
      return AnyLinkError(
        message: message,
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── Spring Boot ───────────────────────────────────────────────────────────
  // {"timestamp":"...","status":400,"error":"...","message":"...","path":"..."}

  static AnyLinkError springBoot(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final message =
          (body['message'] ?? body['error'] ?? 'HTTP ${r.statusCode}').toString();
      return AnyLinkError(
        message: message,
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── Strapi v4 ─────────────────────────────────────────────────────────────
  // {"error":{"status":400,"name":"...","message":"...","details":{}}}

  static AnyLinkError strapi(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      final message = (error?['message'] ?? 'HTTP ${r.statusCode}').toString();
      final errorCode = error?['name'] as String?;
      return AnyLinkError(
        message: message,
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
        errorCode: errorCode,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── FastAPI ───────────────────────────────────────────────────────────────
  // {"detail":[{"loc":["body","email"],"msg":"...","type":"..."}]}

  static AnyLinkError fastApi(AnyLinkResponse r) {
    try {
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is List) {
        final validation = <String, List<String>>{};
        for (final item in detail) {
          if (item is Map) {
            final loc = (item['loc'] as List?)?.map((e) => e.toString()).join('.');
            final msg = item['msg']?.toString() ?? '';
            if (loc != null) {
              validation.putIfAbsent(loc, () => []).add(msg);
            }
          }
        }
        return AnyLinkError(
          message: 'Validation error',
          statusCode: r.statusCode,
          requestPath: r.requestPath,
          requestMethod: r.requestMethod,
          durationMs: r.durationMs,
          response: r,
          validationErrors: validation.isEmpty ? null : validation,
        );
      }
      return AnyLinkError(
        message: detail?.toString() ?? 'HTTP ${r.statusCode}',
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
      );
    } catch (_) {
      return _fallback(r);
    }
  }

  // ── Fallback ──────────────────────────────────────────────────────────────

  static AnyLinkError _fallback(AnyLinkResponse r) => AnyLinkError(
        message: 'HTTP ${r.statusCode}',
        statusCode: r.statusCode,
        requestPath: r.requestPath,
        requestMethod: r.requestMethod,
        durationMs: r.durationMs,
        response: r,
      );
}
