import 'package:any_link/any_link.dart';

/// The outcome of a completed upload.
class UploadResult {
  final String uploadId;
  final String fileName;
  final bool success;
  final String? url;
  final Map<String, dynamic>? serverResponse;
  final AnyLinkError? error;
  final int durationMs;
  final int bytesTransferred;
  final bool deduplicated;

  const UploadResult({
    required this.uploadId,
    required this.fileName,
    required this.success,
    required this.durationMs,
    required this.bytesTransferred,
    this.url,
    this.serverResponse,
    this.error,
    this.deduplicated = false,
  });
}
