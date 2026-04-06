import '../logging/log_sink.dart';
import 'error.dart';

/// Global configuration for [AnyLinkClient].
///
/// Pass to the client constructor. All fields have sensible defaults so you
/// only need to supply [baseUrl] for basic usage.
///
/// ```dart
/// final client = AnyLinkClient(
///   config: AnyLinkConfig(
///     baseUrl: 'https://api.example.com',
///     errorMapper: ErrorMappers.laravel,
///   ),
/// );
/// ```
class AnyLinkConfig {
  /// Base URL prepended to every relative path.
  final String baseUrl;

  /// Named environments. Switch via [currentEnv].
  ///
  /// ```dart
  /// environments: {
  ///   'dev':  'https://dev-api.example.com',
  ///   'prod': 'https://api.example.com',
  /// }
  /// ```
  final Map<String, String>? environments;

  /// Key into [environments] that is currently active. When set, requests use
  /// the matching URL instead of [baseUrl].
  final String? currentEnv;

  /// Maximum time to establish a TCP connection.
  final Duration connectTimeout;

  /// Maximum time to wait for the first byte of the response.
  final Duration receiveTimeout;

  /// Maximum time allowed for the entire request body to be sent.
  final Duration sendTimeout;

  /// Keep-alive idle timeout. Connections are reused until this elapses.
  final Duration idleTimeout;

  /// Maximum simultaneous connections to a single host.
  final int maxConnectionsPerHost;

  /// Headers sent with every request (merged before per-request headers).
  final Map<String, String> defaultHeaders;

  /// Accept-Encoding: gzip, br header added automatically.
  final bool enableCompression;

  /// Attempt HTTP/2 upgrade on native platforms.
  final bool enableHttp2;

  /// Deduplicate identical concurrent GET requests (1 socket, N waiters).
  final bool enableDeduplication;

  /// Automatically generate and attach `Idempotency-Key` for POST/PUT/PATCH.
  final bool enableIdempotencyKeys;

  /// Converts raw error responses into structured [AnyLinkError] objects.
  /// Use one of the presets in [ErrorMappers] or write your own.
  final AnyLinkErrorMapper? errorMapper;

  /// Where log entries are written. Defaults to [ConsoleSink].
  final LogSink logSink;

  const AnyLinkConfig({
    required this.baseUrl,
    this.environments,
    this.currentEnv,
    this.connectTimeout = const Duration(seconds: 10),
    this.receiveTimeout = const Duration(seconds: 15),
    this.sendTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
    this.maxConnectionsPerHost = 6,
    this.defaultHeaders = const {},
    this.enableCompression = true,
    this.enableHttp2 = false,
    this.enableDeduplication = true,
    this.enableIdempotencyKeys = false,
    this.errorMapper,
    this.logSink = const ConsoleSink(),
  });

  /// Resolves a [path] against the active base URL.
  ///
  /// If [path] is already absolute (starts with `http`) it is returned as-is.
  String resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    String? envBase;
    final env = currentEnv;
    if (env != null) envBase = environments?[env];
    final base = envBase ?? baseUrl;
    final trimmedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final trimmedPath = path.startsWith('/') ? path : '/$path';
    return '$trimmedBase$trimmedPath';
  }

  /// Creates a copy with some fields overridden.
  AnyLinkConfig copyWith({
    String? baseUrl,
    Map<String, String>? environments,
    String? currentEnv,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    Duration? idleTimeout,
    int? maxConnectionsPerHost,
    Map<String, String>? defaultHeaders,
    bool? enableCompression,
    bool? enableHttp2,
    bool? enableDeduplication,
    bool? enableIdempotencyKeys,
    AnyLinkErrorMapper? errorMapper,
    LogSink? logSink,
  }) {
    return AnyLinkConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      environments: environments ?? this.environments,
      currentEnv: currentEnv ?? this.currentEnv,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      idleTimeout: idleTimeout ?? this.idleTimeout,
      maxConnectionsPerHost: maxConnectionsPerHost ?? this.maxConnectionsPerHost,
      defaultHeaders: defaultHeaders ?? this.defaultHeaders,
      enableCompression: enableCompression ?? this.enableCompression,
      enableHttp2: enableHttp2 ?? this.enableHttp2,
      enableDeduplication: enableDeduplication ?? this.enableDeduplication,
      enableIdempotencyKeys: enableIdempotencyKeys ?? this.enableIdempotencyKeys,
      errorMapper: errorMapper ?? this.errorMapper,
      logSink: logSink ?? this.logSink,
    );
  }
}
