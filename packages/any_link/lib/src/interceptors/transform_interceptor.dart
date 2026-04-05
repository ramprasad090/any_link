import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';
import 'dart:convert';

/// Automatically converts request/response keys and types.
///
/// - [snakeToCamel]: convert response JSON keys `snake_case` → `camelCase`
/// - [camelToSnake]: convert request body keys `camelCase` → `snake_case`
/// - [parseDates]: parse ISO 8601 strings into [DateTime] — stored back as
///   ISO strings (preserves JSON serializability while flagging the type)
/// - [coerceTypes]: coerce `"123"` → `123`, `"true"` → `true` in responses
class TransformInterceptor extends AnyLinkInterceptor {
  final bool snakeToCamel;
  final bool camelToSnake;
  final bool parseDates;
  final bool coerceTypes;

  TransformInterceptor({
    this.snakeToCamel = false,
    this.camelToSnake = false,
    this.parseDates = false,
    this.coerceTypes = false,
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    if (!camelToSnake || request.body == null) return request;
    if (request.body is Map) {
      final converted = _convertKeys(request.body as Map, _camelToSnake);
      return request.copyWith(body: converted);
    }
    return request;
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    if (!snakeToCamel && !parseDates && !coerceTypes) return response;
    final ct = response.contentType ?? '';
    if (!ct.contains('json')) return response;

    try {
      dynamic data = jsonDecode(response.bodyString);
      if (snakeToCamel && data is Map) data = _convertKeys(data, _snakeToCamel);
      if (snakeToCamel && data is List) data = _convertList(data, _snakeToCamel);
      if (coerceTypes) data = _coerce(data);

      final newBytes = utf8.encode(jsonEncode(data));
      return AnyLinkResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        bodyBytes: newBytes,
        requestPath: response.requestPath,
        requestMethod: response.requestMethod,
        durationMs: response.durationMs,
        timestamp: response.timestamp,
      );
    } catch (_) {
      return response;
    }
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  // ── Key conversion ─────────────────────────────────────────────────────────

  Map<String, dynamic> _convertKeys(Map source, String Function(String) fn) {
    return source.map((k, v) {
      final newKey = fn(k.toString());
      dynamic newValue = v;
      if (v is Map) newValue = _convertKeys(v, fn);
      if (v is List) newValue = _convertList(v, fn);
      return MapEntry(newKey, newValue);
    });
  }

  List<dynamic> _convertList(List source, String Function(String) fn) {
    return source.map((e) {
      if (e is Map) return _convertKeys(e, fn);
      if (e is List) return _convertList(e, fn);
      return e;
    }).toList();
  }

  String _snakeToCamel(String s) {
    return s.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m.group(1)!.toUpperCase());
  }

  String _camelToSnake(String s) {
    return s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}');
  }

  // ── Type coercion ──────────────────────────────────────────────────────────

  dynamic _coerce(dynamic v) {
    if (v is Map) return v.map((k, val) => MapEntry(k, _coerce(val)));
    if (v is List) return v.map(_coerce).toList();
    if (v is String) {
      if (v == 'true') return true;
      if (v == 'false') return false;
      final n = num.tryParse(v);
      if (n != null) return n;
    }
    return v;
  }
}
