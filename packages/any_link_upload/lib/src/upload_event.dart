import 'upload_phase.dart';

/// Emitted by [UploadManager] throughout the upload pipeline.
class UploadEvent {
  final String uploadId;
  final String fileName;
  final UploadPhase phase;
  final int progressPercent;
  final int bytesSent;
  final int bytesTotal;
  final String? speed;
  final String? eta;
  final String? detail;
  final DateTime timestamp;

  const UploadEvent({
    required this.uploadId,
    required this.fileName,
    required this.phase,
    required this.progressPercent,
    required this.bytesSent,
    required this.bytesTotal,
    required this.timestamp,
    this.speed,
    this.eta,
    this.detail,
  });

  @override
  String toString() =>
      'UploadEvent(id: $uploadId, phase: ${phase.runtimeType}, $progressPercent%, '
      '${bytesSent}B/${bytesTotal}B)';
}
