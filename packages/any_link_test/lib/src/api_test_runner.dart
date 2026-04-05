import 'dart:io';
import 'package:any_link/any_link.dart';
import 'api_check.dart';

/// CLI API test runner.
///
/// ```dart
/// // bin/api_check.dart
/// void main() async {
///   final runner = ApiTestRunner(baseUrl: Platform.environment['API_URL'] ?? 'http://localhost:8000');
///
///   runner.group('Auth', [
///     ApiCheck('POST', '/login', body: {'email': 'test@test.com', 'password': 'secret'},
///       expectedStatus: 200, saveAs: 'token', extractField: 'access_token'),
///     ApiCheck('GET', '/user/me', requiresAuth: true, expectedStatus: 200),
///   ]);
///
///   runner.group('Errors', [
///     ApiCheck('GET', '/nonexistent', expectedStatus: 404),
///     ApiCheck('POST', '/login', body: {'email': ''}, expectedStatus: 422),
///   ]);
///
///   await runner.run();
/// }
/// ```
class ApiTestRunner {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  final List<_TestGroup> _groups = [];
  final Map<String, dynamic> _saved = {};

  ApiTestRunner({
    required this.baseUrl,
    this.defaultHeaders = const {},
  });

  /// Register a named group of checks.
  void group(String name, List<ApiCheck> checks) {
    _groups.add(_TestGroup(name: name, checks: checks));
  }

  /// Execute all groups and print a summary.
  Future<void> run() async {
    final client = AnyLinkClient(
      config: AnyLinkConfig(
        baseUrl: baseUrl,
        defaultHeaders: defaultHeaders,
      ),
    );

    int passed = 0;
    int failed = 0;
    final startTime = DateTime.now();

    for (final group in _groups) {
      stdout.writeln('\n  ${group.name}');
      for (final check in group.checks) {
        final result = await _runCheck(client, check);
        if (result.passed) {
          passed++;
        } else {
          failed++;
        }
        stdout.writeln('    $result');
      }
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    final summary = '\n  $passed/${passed + failed} passed · $failed failed · ${duration}ms total';
    stdout.writeln(summary);

    client.close();
    if (failed > 0) exit(1);
  }

  Future<ApiCheckResult> _runCheck(AnyLinkClient client, ApiCheck check) async {
    final sw = Stopwatch()..start();

    try {
      final headers = <String, String>{...defaultHeaders, ...?check.headers};
      if (check.requiresAuth && _saved['token'] != null) {
        headers['Authorization'] = 'Bearer ${_saved["token"]}';
      }

      late AnyLinkResponse response;
      switch (check.method.toUpperCase()) {
        case 'GET':
          response = await client.get(check.path,
              headers: headers, queryParams: check.queryParams);
        case 'POST':
          response = await client.post(check.path, body: check.body, headers: headers);
        case 'PUT':
          response = await client.put(check.path, body: check.body, headers: headers);
        case 'DELETE':
          response = await client.delete(check.path, headers: headers);
        default:
          response = await client.request(
              AnyLinkRequest(method: check.method, path: check.path, headers: headers));
      }

      // Save extracted field.
      if (check.saveAs != null && check.extractField != null) {
        try {
          _saved[check.saveAs!] = response.jsonMap[check.extractField!];
        } catch (_) {}
      }

      sw.stop();
      final passed = response.statusCode == check.expectedStatus;
      return ApiCheckResult(
        check: check,
        passed: passed,
        actualStatus: response.statusCode,
        durationMs: sw.elapsedMilliseconds,
        response: response,
        error: passed ? null : 'Expected ${check.expectedStatus}',
      );
    } on AnyLinkError catch (e) {
      sw.stop();
      final passed = e.statusCode == check.expectedStatus;
      return ApiCheckResult(
        check: check,
        passed: passed,
        actualStatus: e.statusCode ?? 0,
        durationMs: sw.elapsedMilliseconds,
        error: passed ? null : e.message,
      );
    } catch (e) {
      sw.stop();
      return ApiCheckResult(
        check: check,
        passed: false,
        actualStatus: 0,
        durationMs: sw.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }
}

class _TestGroup {
  final String name;
  final List<ApiCheck> checks;
  _TestGroup({required this.name, required this.checks});
}
