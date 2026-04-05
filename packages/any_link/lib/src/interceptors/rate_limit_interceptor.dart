import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import '../interceptors/base_interceptor.dart';
import '../models/request.dart';
import '../models/response.dart';
import '../models/error.dart';

/// Client-side rate limiter. Queues excess requests to prevent accidental
/// hammering of the server (e.g. from infinite-scroll bugs).
///
/// ```dart
/// client.interceptors.add(RateLimitInterceptor(maxRequestsPerSecond: 10));
/// ```
class RateLimitInterceptor extends AnyLinkInterceptor {
  final int maxRequestsPerSecond;
  final bool respectServerHeaders;

  final Queue<_PendingRequest> _queue = Queue();
  int _sentThisSecond = 0;
  Timer? _resetTimer;

  RateLimitInterceptor({
    this.maxRequestsPerSecond = 10,
    this.respectServerHeaders = true,
  });

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    if (_sentThisSecond < maxRequestsPerSecond) {
      _incrementCounter();
      return request;
    }

    // Queue and wait.
    dev.log(
      '⚠️  [any_link] Rate limit reached ($maxRequestsPerSecond req/s). Queuing request: ${request.method} ${request.path}',
      name: 'any_link.rate_limit',
    );

    final completer = Completer<void>();
    _queue.add(_PendingRequest(completer));
    await completer.future;
    _incrementCounter();
    return request;
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async => response;

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;

  void _incrementCounter() {
    _sentThisSecond++;
    _resetTimer ??= Timer(const Duration(seconds: 1), _resetWindow);
  }

  void _resetWindow() {
    _sentThisSecond = 0;
    _resetTimer = null;
    // Drain queue.
    while (_queue.isNotEmpty && _sentThisSecond < maxRequestsPerSecond) {
      _queue.removeFirst().completer.complete();
    }
    if (_queue.isNotEmpty) {
      _resetTimer = Timer(const Duration(seconds: 1), _resetWindow);
    }
  }

  void dispose() {
    _resetTimer?.cancel();
    for (final p in _queue) {
      p.completer.completeError(Exception('RateLimiter disposed'));
    }
    _queue.clear();
  }
}

class _PendingRequest {
  final Completer<void> completer;
  _PendingRequest(this.completer);
}
