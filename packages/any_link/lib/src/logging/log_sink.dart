import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'log_entry.dart';

/// Destination for log output produced by [LogInterceptor].
abstract class LogSink {
  const LogSink();

  /// Called once per [LogEntry]. Must not throw.
  void write(LogEntry entry);
}

// ── ConsoleSink ──────────────────────────────────────────────────────────────

/// Writes colorised, aligned log lines to the console via `dart:developer`.
///
/// Output format:
/// ```
/// 12:34:56.789 ✓ [OrderAPI]   GET  /orders?page=1   → 200 (89ms)
/// 12:34:57.012 ✗ [PaymentAPI] POST /charge           → 500 (3201ms) Gateway timeout
/// 12:34:58.001 🔄 [PaymentAPI] POST /charge           → retry 1/3…
/// ```
class ConsoleSink implements LogSink {
  const ConsoleSink();

  @override
  void write(LogEntry entry) {
    final time = _formatTime(entry.timestamp);
    final icon = entry.error != null ? '✗' : (entry.isRetry ? '🔄' : '✓');
    final status = entry.statusCode != null ? '→ ${entry.statusCode}' : '';
    final duration = '(${entry.durationMs}ms)';
    final err = entry.error != null ? ' ${entry.error}' : '';
    final retry = entry.isRetry ? ' retry ${entry.retryAttempt}…' : '';

    final line = '$time $icon [${entry.prefix}] ${entry.method.padRight(6)} '
        '${entry.path.padRight(40)} $status $duration$err$retry';

    dev.log(line, name: 'any_link');
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';
}

// ── FileSink ─────────────────────────────────────────────────────────────────

/// Appends log lines to a file on disk.
class FileSink implements LogSink {
  final String filePath;
  late final File _file;
  late final IOSink _sink;

  FileSink(this.filePath) {
    _file = File(filePath);
    _sink = _file.openWrite(mode: FileMode.append);
  }

  @override
  void write(LogEntry entry) {
    final line = '${entry.timestamp.toIso8601String()} '
        '[${entry.prefix}] ${entry.method} ${entry.path} '
        '${entry.statusCode ?? "ERR"} ${entry.durationMs}ms'
        '${entry.error != null ? " ${entry.error}" : ""}';
    _sink.writeln(line);
  }

  /// Flush and close the underlying file handle.
  Future<void> close() => _sink.close();
}

// ── StreamSink ───────────────────────────────────────────────────────────────

/// Broadcasts [LogEntry] objects as a [Stream] for in-app debug UIs.
class StreamSink implements LogSink {
  final StreamController<LogEntry> _controller = StreamController.broadcast();

  /// Live stream of log entries.
  Stream<LogEntry> get stream => _controller.stream;

  @override
  void write(LogEntry entry) {
    if (!_controller.isClosed) _controller.add(entry);
  }

  void dispose() => _controller.close();
}
