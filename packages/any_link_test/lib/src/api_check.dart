import 'package:any_link/any_link.dart';

/// A single API test case.
class ApiCheck {
  final String method;
  final String path;
  final dynamic body;
  final Map<String, String>? headers;
  final Map<String, dynamic>? queryParams;
  final int expectedStatus;
  final String? saveAs;
  final String? extractField;
  final bool requiresAuth;
  final String? description;

  const ApiCheck(
    this.method,
    this.path, {
    this.body,
    this.headers,
    this.queryParams,
    this.expectedStatus = 200,
    this.saveAs,
    this.extractField,
    this.requiresAuth = false,
    this.description,
  });
}

/// Result of a single [ApiCheck] execution.
class ApiCheckResult {
  final ApiCheck check;
  final bool passed;
  final int actualStatus;
  final int durationMs;
  final String? error;
  final AnyLinkResponse? response;

  const ApiCheckResult({
    required this.check,
    required this.passed,
    required this.actualStatus,
    required this.durationMs,
    this.error,
    this.response,
  });

  @override
  String toString() {
    final icon = passed ? '✓' : '✗';
    return '$icon ${check.method.padRight(6)} ${check.path.padRight(40)} '
        '→ $actualStatus (${durationMs}ms)${error != null ? " $error" : ""}';
  }
}
