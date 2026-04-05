import 'download_phase.dart';

/// Emitted by [DownloadManager] throughout the download pipeline.
class DownloadEvent {
  final String downloadId;
  final String fileName;
  final DownloadPhase phase;
  final int progressPercent;
  final int bytesReceived;
  final int bytesTotal;
  final String? speed;
  final String? eta;
  final DateTime timestamp;

  const DownloadEvent({
    required this.downloadId,
    required this.fileName,
    required this.phase,
    required this.progressPercent,
    required this.bytesReceived,
    required this.bytesTotal,
    required this.timestamp,
    this.speed,
    this.eta,
  });
}
