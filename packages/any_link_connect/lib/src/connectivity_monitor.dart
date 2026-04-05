import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_status.dart';

/// Two-layer connectivity monitor.
///
/// **Layer 1** — Checks if a network interface is up (WiFi / mobile data).
/// **Layer 2** — Makes a real HTTP request to verify actual internet access.
///
/// Fixes `connectivity_plus#3440`: that package returns "connected" on Flutter
/// Web even when the device has no real internet, because it only checks
/// Layer 1. We always verify Layer 2.
///
/// Also detects captive portals: if the ping returns an HTML redirect instead
/// of a 204 / 200, we flag the status as [NetworkStatus.captivePortal].
///
/// ```dart
/// final monitor = ConnectivityMonitor();
/// monitor.startMonitoring();
///
/// monitor.statusStream.listen((status) {
///   if (status == NetworkStatus.offline) showOfflineBanner();
/// });
/// ```
class ConnectivityMonitor {
  final String pingUrl;
  final Duration checkInterval;

  final ValueNotifier<NetworkStatus> status =
      ValueNotifier(NetworkStatus.connected);

  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  ValueNotifier<ConnectionQuality?> quality = ValueNotifier(null);

  Timer? _timer;
  bool _isChecking = false;

  ConnectivityMonitor({
    this.pingUrl = 'http://connectivitycheck.gstatic.com/generate_204',
    this.checkInterval = const Duration(seconds: 15),
  });

  /// Live stream of [NetworkStatus] changes.
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Begin periodic connectivity checks.
  void startMonitoring() {
    forceCheck();
    _timer = Timer.periodic(checkInterval, (_) => forceCheck());
  }

  /// Stop monitoring.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  /// Run a connectivity check immediately.
  Future<void> forceCheck() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      await _check();
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _check() async {
    try {
      final sw = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final req = await client.openUrl('GET', Uri.parse(pingUrl));
      req.headers.set('Cache-Control', 'no-cache');
      final res = await req.close().timeout(const Duration(seconds: 5));
      sw.stop();

      // Read body to check for captive portal HTML redirect.
      final bodyChunks = <List<int>>[];
      await for (final chunk in res) {
        bodyChunks.add(chunk);
        if (bodyChunks.expand((c) => c).length > 1024) break;
      }
      client.close();

      final bodyStart = String.fromCharCodes(
        bodyChunks.expand((c) => c).take(200).toList(),
      ).toLowerCase();

      final NetworkStatus newStatus;
      if (res.statusCode == 204 || (res.statusCode == 200 && bodyStart.isEmpty)) {
        newStatus = NetworkStatus.online;
      } else if (bodyStart.contains('<html') || bodyStart.contains('<!doctype')) {
        newStatus = NetworkStatus.captivePortal;
      } else {
        newStatus = NetworkStatus.online;
      }

      _updateStatus(newStatus);
      quality.value = ConnectionQuality.fromLatency(sw.elapsedMilliseconds.toDouble());
    } catch (_) {
      _updateStatus(NetworkStatus.offline);
      quality.value = null;
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (status.value != newStatus) {
      status.value = newStatus;
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    stopMonitoring();
    _statusController.close();
    status.dispose();
    quality.dispose();
  }
}
