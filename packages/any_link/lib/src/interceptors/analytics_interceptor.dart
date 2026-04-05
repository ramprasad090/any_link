import 'dart:async';
import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Per-endpoint statistics snapshot.
class EndpointStats {
  final String path;
  int callCount;
  int errorCount;
  int totalResponseMs;
  int totalBytesSent;
  int totalBytesReceived;
  int cacheHits;
  final List<int> _responseTimes = [];

  EndpointStats(this.path)
      : callCount = 0,
        errorCount = 0,
        totalResponseMs = 0,
        totalBytesSent = 0,
        totalBytesReceived = 0,
        cacheHits = 0;

  double get avgResponseMs => callCount == 0 ? 0 : totalResponseMs / callCount;
  double get errorRate => callCount == 0 ? 0 : errorCount / callCount;
  double get cacheHitRatio => callCount == 0 ? 0 : cacheHits / callCount;

  double get p95ResponseMs {
    if (_responseTimes.isEmpty) return 0;
    final sorted = List<int>.from(_responseTimes)..sort();
    final idx = ((sorted.length * 0.95) - 1).round().clamp(0, sorted.length - 1);
    return sorted[idx].toDouble();
  }
}

/// An analytics event emitted per request.
class AnalyticsEvent {
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final bool isError;
  final bool isCacheHit;
  final DateTime timestamp;

  const AnalyticsEvent({
    required this.method,
    required this.path,
    required this.durationMs,
    required this.timestamp,
    this.statusCode,
    this.isError = false,
    this.isCacheHit = false,
  });
}

/// Collects per-endpoint performance metrics and exposes them as a stream.
///
/// ```dart
/// final analytics = AnalyticsInterceptor();
/// client.interceptors.add(analytics);
///
/// analytics.analyticsStream.listen((event) { ... });
/// print(analytics.getStats()['/orders']?.avgResponseMs);
/// ```
class AnalyticsInterceptor extends AnyLinkInterceptor {
  final Map<String, EndpointStats> _stats = {};
  final StreamController<AnalyticsEvent> _controller =
      StreamController<AnalyticsEvent>.broadcast();

  /// Live stream of analytics events.
  Stream<AnalyticsEvent> get analyticsStream => _controller.stream;

  /// Snapshot of per-endpoint statistics.
  Map<String, EndpointStats> getStats() => Map.unmodifiable(_stats);

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async => request;

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    _record(response.requestPath, response.requestMethod,
        response.statusCode, response.durationMs, false);
    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    _record(error.requestPath ?? '?', error.requestMethod ?? '?',
        error.statusCode, error.durationMs ?? 0, true);
    return error;
  }

  void _record(String path, String method, int? statusCode, int ms, bool isError) {
    final stats = _stats.putIfAbsent(path, () => EndpointStats(path));
    stats.callCount++;
    stats.totalResponseMs += ms;
    stats._responseTimes.add(ms);
    if (isError) stats.errorCount++;

    final event = AnalyticsEvent(
      method: method,
      path: path,
      statusCode: statusCode,
      durationMs: ms,
      timestamp: DateTime.now(),
      isError: isError,
    );
    if (!_controller.isClosed) _controller.add(event);
  }

  void dispose() => _controller.close();
}
