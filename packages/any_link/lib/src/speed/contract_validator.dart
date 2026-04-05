import 'dart:developer' as dev;
import '../models/response.dart';

/// Registers expected response schemas and validates them at runtime.
///
/// Catches backend breaking changes — missing fields, wrong types — before
/// they crash the app in production.
///
/// ```dart
/// final validator = ContractValidator()
///   ..register('/user/me', {'id': int, 'email': String, 'name': String})
///   ..register('/orders', {'data': List, 'meta': Map});
/// ```
class ContractValidator {
  final Map<String, Map<String, Type>> _schemas = {};

  /// Register the expected field types for a path.
  ContractValidator register(String path, Map<String, Type> schema) {
    _schemas[path] = schema;
    return this;
  }

  /// Validate a [response]. Logs warnings for violations.
  /// In debug mode violations throw; in release mode they are silently logged.
  void validate(AnyLinkResponse response) {
    final schema = _schemas[response.requestPath];
    if (schema == null) return;

    try {
      final json = response.jsonMap;
      for (final entry in schema.entries) {
        final field = entry.key;
        final expectedType = entry.value;
        final value = json[field];

        if (value == null) {
          _warn('Missing field "$field" in ${response.requestPath}');
        } else if (!_isType(value, expectedType)) {
          _warn('Field "$field" expected $expectedType but got ${value.runtimeType} in ${response.requestPath}');
        }
      }
    } catch (_) {
      // Not a JSON object — skip validation.
    }
  }

  bool _isType(dynamic value, Type type) {
    if (type == int) return value is int;
    if (type == double) return value is double || value is int;
    if (type == String) return value is String;
    if (type == bool) return value is bool;
    if (type == List) return value is List;
    if (type == Map) return value is Map;
    return true;
  }

  void _warn(String msg) {
    dev.log('⚠️  [ContractValidator] $msg', name: 'any_link.contract');
    assert(false, msg); // Throws in debug, silent in release.
  }
}
