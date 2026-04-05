import 'dart:convert';
import 'dart:io';
import 'package:any_link/any_link.dart';

/// VCR-style request recorder for deterministic testing.
///
/// **Record mode**: intercepts real requests and saves them as JSON fixtures.
/// **Replay mode**: serves saved fixtures without hitting the network.
///
/// ```dart
/// // Record once:
/// final recorder = RequestRecorder(directory: 'test/fixtures', mode: RecorderMode.record);
/// client.interceptors.add(recorder.interceptor);
///
/// // Then replay in CI:
/// final recorder = RequestRecorder(directory: 'test/fixtures', mode: RecorderMode.replay);
/// client.interceptors.add(recorder.interceptor);
/// ```
enum RecorderMode { record, replay, passThrough }

class RequestRecorder {
  final String directory;
  final RecorderMode mode;

  RequestRecorder({required this.directory, this.mode = RecorderMode.replay}) {
    Directory(directory).createSync(recursive: true);
  }

  AnyLinkInterceptor get interceptor => _RecorderInterceptor(this);

  String _fixtureFile(String method, String path) {
    final safe = '${method}_${path.replaceAll('/', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-')}';
    return '$directory/$safe.json';
  }

  Future<AnyLinkResponse?> getRecorded(String method, String path) async {
    final file = File(_fixtureFile(method, path));
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return AnyLinkResponse(
      statusCode: json['statusCode'] as int,
      headers: Map<String, String>.from(json['headers'] as Map),
      bodyBytes: List<int>.from(json['bodyBytes'] as List),
      requestPath: path,
      requestMethod: method,
      durationMs: json['durationMs'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Future<void> record(AnyLinkResponse response) async {
    final file = File(_fixtureFile(response.requestMethod, response.requestPath));
    await file.writeAsString(jsonEncode({
      'statusCode': response.statusCode,
      'headers': response.headers,
      'bodyBytes': response.bodyBytes,
      'durationMs': response.durationMs,
      'timestamp': response.timestamp.toIso8601String(),
    }));
  }
}

class _RecorderInterceptor extends AnyLinkInterceptor {
  final RequestRecorder recorder;
  _RecorderInterceptor(this.recorder);

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    if (recorder.mode == RecorderMode.record) {
      await recorder.record(response);
    }
    return response;
  }
}
