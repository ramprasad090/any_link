import 'dart:async';
import 'package:flutter/material.dart';
import '../upload_event.dart';
import '../upload_manager.dart';
import '../upload_phase.dart';
import '../upload_request.dart';

/// Drop-in upload progress widget.
///
/// Shows per-file progress bar, speed, ETA, cancel and retry buttons.
///
/// ```dart
/// UploadProgressWidget(
///   manager: uploadManager,
///   request: UploadRequest(filePath: path, endpoint: '/uploads'),
///   onComplete: (result) => print('URL: ${result.url}'),
/// )
/// ```
class UploadProgressWidget extends StatefulWidget {
  final UploadManager manager;
  final UploadRequest request;
  final void Function(dynamic result)? onComplete;
  final void Function(dynamic error)? onError;

  const UploadProgressWidget({
    super.key,
    required this.manager,
    required this.request,
    this.onComplete,
    this.onError,
  });

  @override
  State<UploadProgressWidget> createState() => _UploadProgressWidgetState();
}

class _UploadProgressWidgetState extends State<UploadProgressWidget> {
  UploadEvent? _lastEvent;
  late final StreamSubscription<UploadEvent> _sub;
  String? _uploadId;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.manager.events.listen((event) {
      if (_uploadId == null || event.uploadId == _uploadId) {
        setState(() => _lastEvent = event);
        if (event.phase is UploadComplete) widget.onComplete?.call(event);
        if (event.phase is UploadFailed) widget.onError?.call(event.phase);
      }
    });
    _startUpload();
  }

  void _startUpload() async {
    _started = true;
    final result = await widget.manager.upload(widget.request);
    _uploadId = result.uploadId;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _lastEvent;
    if (event == null) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final phase = event.phase;
    final isComplete = phase is UploadComplete;
    final isFailed = phase is UploadFailed;
    final isCancelled = phase is UploadCancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.fileName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isComplete && !isFailed && !isCancelled)
                  TextButton(
                    onPressed: () => widget.manager.cancel(event.uploadId),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: isComplete ? 1.0 : isFailed ? 0 : event.progressPercent / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isFailed ? Colors.red : isComplete ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_phaseLabel(phase), style: const TextStyle(fontSize: 12)),
                if (event.speed != null)
                  Text(event.speed!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (event.eta != null && !isComplete)
                  Text('ETA ${event.eta}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (event.detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(event.detail!,
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(UploadPhase phase) => switch (phase) {
        Validating() => 'Validating…',
        Compressing(:final originalSize, :final compressedSize) =>
          compressedSize == null ? 'Compressing…' : 'Compressed ✓',
        Hashing() => 'Checking for duplicates…',
        Uploading() => '${_lastEvent?.progressPercent ?? 0}%',
        ServerProcessing() => 'Processing on server…',
        Retrying(:final attempt, :final maxAttempts) => 'Retry $attempt/$maxAttempts…',
        UploadComplete() => 'Upload complete ✓',
        UploadFailed(:final error) => 'Failed: $error',
        UploadCancelled() => 'Cancelled',
      };
}
