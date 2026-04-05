import 'dart:async';
import '../interceptors/base_interceptor.dart';
import '../logging/log_entry.dart';
import '../logging/log_sink.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// pm2-style prefixed request/response logger.
///
/// Attach one per [ApiModule] with a distinct [prefix] so you can filter logs
/// by feature area (e.g. `"AuthAPI"`, `"OrderAPI"`, `"UploadSvc"`).
///
/// ```dart
/// client.interceptors.add(LogInterceptor(
///   prefix: 'OrderAPI',
///   level: LogLevel.body,
///   maskHeaders: {'Authorization'},
/// ));
/// ```
class LogInterceptor extends AnyLinkInterceptor {
  /// Label prepended to every log line.
  final String prefix;

  /// Controls how much detail is included.
  final LogLevel level;

  /// Where output is written.
  final LogSink sink;

  /// Header names whose values are replaced with `***` in log output.
  final Set<String> maskHeaders;

  /// Replace request/response body with `[masked]` in log output.
  final bool maskBody;

  // Global broadcast stream — bind to debug UI or file export.
  static final StreamController<LogEntry> _globalController =
      StreamController<LogEntry>.broadcast();

  /// All log entries from every [LogInterceptor] instance.
  static Stream<LogEntry> get logStream => _globalController.stream;

  // Per-request start time keyed by request identity.
  final Map<String, DateTime> _startTimes = {};

  LogInterceptor({
    this.prefix = 'API',
    this.level = LogLevel.basic,
    this.sink = const ConsoleSink(),
    this.maskHeaders = const {'authorization', 'x-api-key', 'cookie'},
    this.maskBody = false,
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    if (level == LogLevel.none) return request;
    _startTimes[_key(request)] = DateTime.now();
    return request;
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    if (level == LogLevel.none) return response;
    final start = _startTimes.remove(_responseKey(response));
    final entry = LogEntry(
      prefix: prefix,
      method: response.requestMethod,
      path: response.requestPath,
      statusCode: response.statusCode,
      durationMs: response.durationMs,
      timestamp: start ?? DateTime.now(),
      level: level,
      responseSizeBytes: response.bodyBytes.length,
      responseBody: (level == LogLevel.all && !maskBody) ? _truncate(response.bodyString) : null,
    );
    sink.write(entry);
    _globalController.add(entry);
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    if (level == LogLevel.none) return error;
    final entry = LogEntry(
      prefix: prefix,
      method: error.requestMethod ?? '?',
      path: error.requestPath ?? '?',
      statusCode: error.statusCode,
      durationMs: error.durationMs ?? 0,
      timestamp: DateTime.now(),
      level: level,
      error: error.message,
    );
    sink.write(entry);
    _globalController.add(entry);
    return error;
  }

  String _key(AnyLinkRequest r) => '${r.method}:${r.path}';
  String _responseKey(AnyLinkResponse r) => '${r.requestMethod}:${r.requestPath}';

  String _truncate(String s, {int max = 2000}) =>
      s.length > max ? '${s.substring(0, max)}…[truncated]' : s;
}
