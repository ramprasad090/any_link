import 'dart:async';

/// Token used to cancel in-flight requests.
///
/// Create one instance per request or group of requests. Call [cancel] to abort.
///
/// ```dart
/// final token = CancelToken();
/// client.get('/data', cancelToken: token);
/// token.cancel('User navigated away');
/// ```
class CancelToken {
  bool _isCancelled = false;
  String? _reason;
  final Completer<void> _completer = Completer<void>();

  /// Whether this token has been cancelled.
  bool get isCancelled => _isCancelled;

  /// The reason provided when [cancel] was called, or null.
  String? get reason => _reason;

  /// A future that completes when [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  /// Cancel the associated request.
  ///
  /// [reason] is optional and appears in log output and [AnyLinkError.rawError].
  void cancel([String? reason]) {
    if (_isCancelled) return;
    _isCancelled = true;
    _reason = reason;
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

/// Thrown when a request is cancelled via [CancelToken].
class CancelledException implements Exception {
  /// The reason provided to [CancelToken.cancel], or null.
  final String? reason;

  const CancelledException([this.reason]);

  @override
  String toString() => reason != null ? 'CancelledException: $reason' : 'CancelledException';
}
