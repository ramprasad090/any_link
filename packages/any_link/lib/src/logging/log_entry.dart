/// Severity / verbosity level for [LogInterceptor].
enum LogLevel {
  /// No output.
  none,

  /// One-line summary: method, path, status, duration.
  basic,

  /// Basic + request and response headers.
  headers,

  /// Headers + request body.
  body,

  /// Everything including response body.
  all,
}

/// A single captured HTTP interaction.
class LogEntry {
  final String prefix;
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final DateTime timestamp;
  final String? error;
  final LogLevel level;
  final Map<String, String>? requestHeaders;
  final dynamic requestBody;
  final dynamic responseBody;
  final int? requestSizeBytes;
  final int? responseSizeBytes;
  final bool isRetry;
  final int retryAttempt;

  const LogEntry({
    required this.prefix,
    required this.method,
    required this.path,
    required this.durationMs,
    required this.timestamp,
    required this.level,
    this.statusCode,
    this.error,
    this.requestHeaders,
    this.requestBody,
    this.responseBody,
    this.requestSizeBytes,
    this.responseSizeBytes,
    this.isRetry = false,
    this.retryAttempt = 0,
  });
}
