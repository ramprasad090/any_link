import 'dart:async';
import 'dart:io';
import 'package:any_link/any_link.dart';

/// Load test result summary.
class LoadTestReport {
  final int totalRequests;
  final int successCount;
  final int errorCount;
  final double avgResponseMs;
  final double p50ResponseMs;
  final double p95ResponseMs;
  final double p99ResponseMs;
  final double requestsPerSecond;
  final Duration totalDuration;

  const LoadTestReport({
    required this.totalRequests,
    required this.successCount,
    required this.errorCount,
    required this.avgResponseMs,
    required this.p50ResponseMs,
    required this.p95ResponseMs,
    required this.p99ResponseMs,
    required this.requestsPerSecond,
    required this.totalDuration,
  });

  void printReport() {
    stdout.writeln('\n  Load Test Results');
    stdout.writeln('  ─────────────────────────────────────');
    stdout.writeln('  Total requests: $totalRequests');
    stdout.writeln('  Success: $successCount  Errors: $errorCount');
    stdout.writeln('  Duration: ${totalDuration.inSeconds}s');
    stdout.writeln('  RPS: ${requestsPerSecond.toStringAsFixed(1)}');
    stdout.writeln('  Latency: avg ${avgResponseMs.toStringAsFixed(0)}ms  '
        'p50 ${p50ResponseMs.toStringAsFixed(0)}ms  '
        'p95 ${p95ResponseMs.toStringAsFixed(0)}ms  '
        'p99 ${p99ResponseMs.toStringAsFixed(0)}ms');
  }
}

/// Simple load tester that fires concurrent requests for a given duration.
///
/// ```dart
/// // dart run any_link_test:load --url=https://api.example.com/health
/// final report = await LoadTester(
///   url: 'https://api.example.com/health',
///   concurrency: 50,
///   duration: Duration(seconds: 30),
/// ).run();
/// report.printReport();
/// ```
class LoadTester {
  final String url;
  final int concurrency;
  final Duration duration;

  LoadTester({required this.url, this.concurrency = 10, required this.duration});

  Future<LoadTestReport> run() async {
    final client = AnyLinkClient(
      config: AnyLinkConfig(baseUrl: url),
    );

    final responseTimes = <int>[];
    int success = 0;
    int errors = 0;
    final stopwatch = Stopwatch()..start();
    final end = DateTime.now().add(duration);

    Future<void> worker() async {
      while (DateTime.now().isBefore(end)) {
        final sw = Stopwatch()..start();
        try {
          await client.get('/');
          sw.stop();
          responseTimes.add(sw.elapsedMilliseconds);
          success++;
        } catch (_) {
          sw.stop();
          responseTimes.add(sw.elapsedMilliseconds);
          errors++;
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    client.close();
    stopwatch.stop();

    responseTimes.sort();
    final n = responseTimes.length;
    final avg = n > 0 ? responseTimes.reduce((a, b) => a + b) / n : 0.0;

    return LoadTestReport(
      totalRequests: n,
      successCount: success,
      errorCount: errors,
      avgResponseMs: avg,
      p50ResponseMs: n > 0 ? responseTimes[(n * 0.50).floor()].toDouble() : 0,
      p95ResponseMs: n > 0 ? responseTimes[(n * 0.95).floor()].toDouble() : 0,
      p99ResponseMs: n > 0 ? responseTimes[(n * 0.99).floor()].toDouble() : 0,
      requestsPerSecond: n / stopwatch.elapsed.inSeconds.clamp(1, 999999),
      totalDuration: stopwatch.elapsed,
    );
  }
}
