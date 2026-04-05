import 'dart:async';
import 'package:any_link/any_link.dart';

/// An in-memory log of HTTP interactions for display in the inspector panel.
class NetworkInspector {
  final int maxEntries;
  final List<LogEntry> _logs = [];
  final StreamController<List<LogEntry>> _controller =
      StreamController<List<LogEntry>>.broadcast();

  StreamSubscription<LogEntry>? _sub;

  NetworkInspector({this.maxEntries = 500});

  /// Live stream of the log list (updated on every new entry).
  Stream<List<LogEntry>> get logsStream => _controller.stream;

  /// Current snapshot of log entries (newest first).
  List<LogEntry> get logs => List.unmodifiable(_logs.reversed.toList());

  /// Start capturing from [LogInterceptor.logStream].
  void startCapturing() {
    _sub = LogInterceptor.logStream.listen((entry) {
      _logs.add(entry);
      if (_logs.length > maxEntries) _logs.removeAt(0);
      _controller.add(logs);
    });
  }

  void stopCapturing() => _sub?.cancel();

  void clear() {
    _logs.clear();
    _controller.add([]);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
