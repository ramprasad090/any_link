/// CLI entry point: `dart run any_link_test:api_check`
///
/// Reads `API_URL` from environment. Looks for `test/api_checks.dart` or runs
/// a built-in smoke test if no file found.
///
/// ```sh
/// API_URL=https://staging.api.com dart run any_link_test:api_check
/// ```
import 'dart:io';
import 'package:any_link_test/any_link_test.dart';

Future<void> main(List<String> args) async {
  final url = Platform.environment['API_URL'] ?? 'http://localhost:8000';
  stdout.writeln('any_link API check runner');
  stdout.writeln('Base URL: $url\n');

  final runner = ApiTestRunner(baseUrl: url);
  runner.group('Health', [
    const ApiCheck('GET', '/', expectedStatus: 200, description: 'Health check'),
  ]);

  await runner.run();
}
