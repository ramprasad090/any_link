import 'dart:io';

/// Performs DNS lookups on app startup to eliminate ~50–200 ms latency
/// from the very first API request after a cold start.
///
/// ```dart
/// // In main() or initState() before first navigation:
/// await DnsPreResolver.preResolve(['api.example.com', 'cdn.example.com']);
/// ```
class DnsPreResolver {
  DnsPreResolver._();

  /// Resolves all [hosts] concurrently. Errors per host are silently ignored
  /// (resolution is best-effort; the OS will retry on the actual request).
  static Future<void> preResolve(List<String> hosts) async {
    await Future.wait(
      hosts.map((host) => InternetAddress.lookup(host).catchError((_) => <InternetAddress>[])),
    );
  }
}
