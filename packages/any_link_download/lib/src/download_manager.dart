import 'dart:async';
import 'dart:io';
import 'package:any_link/any_link.dart';
import 'download_event.dart';
import 'download_phase.dart';
import 'download_request.dart';

/// Manages file downloads with real progress, pause/resume, parallel chunks.
///
/// ```dart
/// final manager = DownloadManager(client: anyLinkClient);
///
/// manager.events.listen((e) => print('${e.fileName}: ${e.progressPercent}%'));
///
/// final file = await manager.download(DownloadRequest(
///   url: 'https://example.com/video.mp4',
///   savePath: '/storage/video.mp4',
///   parallelChunks: true,
///   chunkCount: 4,
/// ));
/// ```
class DownloadManager {
  final AnyLinkClient client;

  final StreamController<DownloadEvent> _eventController =
      StreamController<DownloadEvent>.broadcast();

  final Map<String, bool> _cancelled = {};
  final Map<String, bool> _paused = {};
  final Map<String, int> _resumeBytes = {};

  DownloadManager({required this.client});

  /// Stream of all download events.
  Stream<DownloadEvent> get events => _eventController.stream;

  /// Download a single file.
  Future<File> download(DownloadRequest request) async {
    final id = request.id ?? _generateId();
    _cancelled[id] = false;
    _paused[id] = false;

    final fileName = request.savePath.split('/').last;
    _emit(id, fileName, const DownloadConnecting(), 0, 0, 0);

    if (request.parallelChunks) {
      return _parallelDownload(id, request, fileName);
    }
    return _simpleDownload(id, request, fileName);
  }

  /// Download multiple files, at most [concurrency] at a time.
  Future<List<File>> downloadMultiple(
    List<DownloadRequest> requests, {
    int concurrency = 3,
  }) async {
    final results = <File>[];
    for (var i = 0; i < requests.length; i += concurrency) {
      final batch = requests.skip(i).take(concurrency).toList();
      final batchResults = await Future.wait(batch.map(download));
      results.addAll(batchResults);
    }
    return results;
  }

  void cancel(String downloadId) => _cancelled[downloadId] = true;
  void pause(String downloadId) => _paused[downloadId] = true;
  void resume(String downloadId) => _paused[downloadId] = false;

  void dispose() => _eventController.close();

  // ── Simple / resumable download ───────────────────────────────────────────

  Future<File> _simpleDownload(String id, DownloadRequest request, String fileName) async {
    final saveFile = File(request.savePath);
    int startByte = 0;

    if (request.resumable && await saveFile.exists()) {
      startByte = await saveFile.length();
      _resumeBytes[id] = startByte;
    }

    for (var attempt = 0; attempt <= request.maxRetries; attempt++) {
      if (_cancelled[id] == true) {
        _emit(id, fileName, const DownloadCancelled(), 0, startByte, 0);
        return saveFile;
      }

      try {
        final headers = <String, String>{...?request.headers};
        if (startByte > 0) headers['Range'] = 'bytes=$startByte-';

        final response = await client.get(
          request.url,
          headers: headers,
          onReceiveProgress: (received, total) {
            if (_cancelled[id] == true) return;
            final realTotal = total > 0 ? total + startByte : 0;
            final realReceived = received + startByte;
            final percent = realTotal > 0 ? ((realReceived / realTotal) * 100).clamp(0, 100).round() : 0;
            _emit(id, fileName, const Downloading(), percent, realReceived, realTotal);
          },
        );

        // Write to disk.
        final mode = startByte > 0 ? FileMode.append : FileMode.write;
        final sink = saveFile.openWrite(mode: mode);
        sink.add(response.bodyBytes);
        await sink.close();

        _emit(id, fileName, DownloadComplete(savedPath: request.savePath), 100,
            await saveFile.length(), await saveFile.length());
        return saveFile;
      } catch (_) {
        if (attempt == request.maxRetries) {
          _emit(id, fileName, const DownloadFailed(error: 'Max retries exceeded'), 0, 0, 0);
          rethrow;
        }
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
    return saveFile;
  }

  // ── Parallel chunk download ───────────────────────────────────────────────

  Future<File> _parallelDownload(String id, DownloadRequest request, String fileName) async {
    // Get file size first.
    final headResponse = await client.head(request.url, headers: request.headers);
    final contentLength = headResponse.contentLength ?? 0;

    if (contentLength == 0) {
      return _simpleDownload(id, request, fileName);
    }

    final chunkSize = (contentLength / request.chunkCount).ceil();
    final chunkFiles = <File>[];

    // Download all chunks in parallel.
    await Future.wait(List.generate(request.chunkCount, (i) async {
      final start = i * chunkSize;
      final end = (start + chunkSize - 1).clamp(0, contentLength - 1);
      final chunkFile = File('${request.savePath}.chunk$i');
      chunkFiles.add(chunkFile);

      final headers = <String, String>{...?request.headers, 'Range': 'bytes=$start-$end'};
      final response = await client.get(request.url, headers: headers);
      await chunkFile.writeAsBytes(response.bodyBytes);
    }));

    _emit(id, fileName, const MergingChunks(), 99, contentLength, contentLength);

    // Merge chunks.
    final saveFile = File(request.savePath);
    final sink = saveFile.openWrite();
    for (final chunk in chunkFiles) {
      sink.add(await chunk.readAsBytes());
      await chunk.delete();
    }
    await sink.close();

    _emit(id, fileName, DownloadComplete(savedPath: request.savePath), 100, contentLength, contentLength);
    return saveFile;
  }

  void _emit(String id, String fileName, DownloadPhase phase, int percent, int received, int total) {
    if (_eventController.isClosed) return;
    _eventController.add(DownloadEvent(
      downloadId: id,
      fileName: fileName,
      phase: phase,
      progressPercent: percent,
      bytesReceived: received,
      bytesTotal: total,
      timestamp: DateTime.now(),
    ));
  }

  static String _generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);
}
