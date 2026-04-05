import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:any_link/any_link.dart';

/// Exports captured request/response logs as an HTTP Archive (.har) file.
///
/// HAR files can be imported into Chrome DevTools, Postman, Charles Proxy, etc.
///
/// ```dart
/// final exporter = HarExporter(logStream: LogInterceptor.logStream);
/// // ... use the app ...
/// await exporter.export('debug_session.har');
/// ```
class HarExporter {
  final Stream<LogEntry> logStream;
  final List<LogEntry> _entries = [];
  late final StreamSubscription<LogEntry> _sub;

  HarExporter({required this.logStream}) {
    _sub = logStream.listen(_entries.add);
  }

  /// Write all captured log entries to [filePath] in HAR format.
  Future<void> export(String filePath) async {
    final har = {
      'log': {
        'version': '1.2',
        'creator': {'name': 'any_link', 'version': '1.0.0'},
        'entries': _entries.map(_entryToHar).toList(),
      }
    };
    await File(filePath).writeAsString(const JsonEncoder.withIndent('  ').convert(har));
  }

  Map<String, dynamic> _entryToHar(LogEntry entry) => {
        'startedDateTime': entry.timestamp.toIso8601String(),
        'time': entry.durationMs,
        'request': {
          'method': entry.method,
          'url': entry.path,
          'httpVersion': 'HTTP/1.1',
          'headers': entry.requestHeaders
                  ?.entries
                  .map((e) => {'name': e.key, 'value': e.value})
                  .toList() ??
              [],
          'queryString': [],
          'bodySize': entry.requestSizeBytes ?? -1,
        },
        'response': {
          'status': entry.statusCode ?? 0,
          'statusText': '',
          'httpVersion': 'HTTP/1.1',
          'headers': [],
          'content': {
            'size': entry.responseSizeBytes ?? -1,
            'mimeType': 'application/json',
          },
          'bodySize': entry.responseSizeBytes ?? -1,
          'redirectURL': '',
        },
        'timings': {'send': 0, 'wait': entry.durationMs, 'receive': 0},
      };

  void dispose() => _sub.cancel();
}
