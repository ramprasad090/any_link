import 'dart:async';
import 'package:flutter/material.dart';
import '../download_event.dart';
import '../download_manager.dart';
import '../download_phase.dart';
import '../download_request.dart';

/// Drop-in download progress widget.
class DownloadProgressWidget extends StatefulWidget {
  final DownloadManager manager;
  final DownloadRequest request;
  final void Function(String savedPath)? onComplete;
  final void Function(String error)? onError;

  const DownloadProgressWidget({
    super.key,
    required this.manager,
    required this.request,
    this.onComplete,
    this.onError,
  });

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget> {
  DownloadEvent? _lastEvent;
  late final StreamSubscription<DownloadEvent> _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.manager.events.listen((event) {
      setState(() => _lastEvent = event);
      if (event.phase is DownloadComplete) {
        widget.onComplete?.call((event.phase as DownloadComplete).savedPath);
      }
      if (event.phase is DownloadFailed) {
        widget.onError?.call((event.phase as DownloadFailed).error);
      }
    });
    widget.manager.download(widget.request);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _lastEvent;
    if (event == null) return const LinearProgressIndicator();

    final phase = event.phase;
    final isComplete = phase is DownloadComplete;
    final isFailed = phase is DownloadFailed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(event.fileName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                ),
                if (!isComplete && !isFailed)
                  TextButton(
                    onPressed: () => widget.manager.cancel(event.downloadId),
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
            Text(_phaseLabel(phase), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(DownloadPhase phase) => switch (phase) {
        DownloadPending() => 'Waiting…',
        DownloadConnecting() => 'Connecting…',
        Downloading() => '${_lastEvent?.progressPercent ?? 0}%',
        MergingChunks() => 'Merging chunks…',
        VerifyingIntegrity() => 'Verifying…',
        DownloadComplete(:final savedPath) => 'Saved to $savedPath ✓',
        DownloadFailed(:final error) => 'Failed: $error',
        DownloadCancelled() => 'Cancelled',
        DownloadPaused(:final bytesReceived) => 'Paused (${bytesReceived}B received)',
      };
}
