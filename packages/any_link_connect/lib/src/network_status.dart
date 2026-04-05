/// The current network reachability status.
enum NetworkStatus {
  /// No network interface is connected.
  offline,

  /// Network interface is up but actual internet access is unknown (initial state).
  connected,

  /// Network interface is up AND real HTTP connectivity confirmed.
  online,

  /// Network responds but redirects to a login page (hotel/airport WiFi).
  captivePortal,
}

/// Estimated quality level of the current connection.
enum QualityLevel { good, fair, slow, unstable }

/// Snapshot of connection quality metrics.
class ConnectionQuality {
  /// Round-trip ping time in milliseconds.
  final double latencyMs;

  /// Estimated downstream bandwidth in Mbps.
  final double bandwidthMbps;

  /// Variance in latency (std dev, ms).
  final double jitter;

  /// Overall quality classification.
  final QualityLevel level;

  const ConnectionQuality({
    required this.latencyMs,
    required this.bandwidthMbps,
    required this.jitter,
    required this.level,
  });

  factory ConnectionQuality.fromLatency(double latencyMs) {
    final QualityLevel level;
    if (latencyMs < 100) {
      level = QualityLevel.good;
    } else if (latencyMs < 300) {
      level = QualityLevel.fair;
    } else if (latencyMs < 1000) {
      level = QualityLevel.slow;
    } else {
      level = QualityLevel.unstable;
    }
    return ConnectionQuality(
      latencyMs: latencyMs,
      bandwidthMbps: 0,
      jitter: 0,
      level: level,
    );
  }
}
