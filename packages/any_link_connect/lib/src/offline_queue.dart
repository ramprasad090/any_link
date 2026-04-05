import 'dart:async';
import 'dart:collection';
import 'package:any_link/any_link.dart';
import 'connectivity_monitor.dart';
import 'network_status.dart';

/// A queued request waiting to be replayed.
class QueuedRequest {
  final AnyLinkRequest request;
  final DateTime queuedAt;
  final Duration ttl;
  final String id;

  QueuedRequest({
    required this.request,
    required this.ttl,
    required this.id,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(queuedAt) > ttl;
}

/// An event emitted by [OfflineQueue].
class OfflineQueueEvent {
  final String type; // 'queued', 'replaying', 'replayed', 'expired', 'failed'
  final QueuedRequest request;
  final AnyLinkResponse? response;
  final AnyLinkError? error;

  const OfflineQueueEvent({
    required this.type,
    required this.request,
    this.response,
    this.error,
  });
}

/// Queues mutating requests (POST/PUT/PATCH/DELETE) when offline and replays
/// them in order when connectivity is restored.
///
/// ```dart
/// final queue = OfflineQueue(
///   client: anyLinkClient,
///   monitor: connectivityMonitor,
/// );
///
/// // When offline, enqueue instead of calling client directly:
/// queue.enqueue(AnyLinkRequest(method: 'POST', path: '/orders', body: {...}));
/// print('${queue.pendingCount} requests will be sent when online');
/// ```
class OfflineQueue {
  final AnyLinkClient client;
  final ConnectivityMonitor monitor;
  final int maxQueueSize;
  final Duration defaultTtl;

  final Queue<QueuedRequest> _queue = Queue();
  final StreamController<OfflineQueueEvent> _eventController =
      StreamController<OfflineQueueEvent>.broadcast();

  late final StreamSubscription<NetworkStatus> _statusSub;

  static const _mutatingMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

  OfflineQueue({
    required this.client,
    required this.monitor,
    this.maxQueueSize = 100,
    this.defaultTtl = const Duration(hours: 24),
  }) {
    _statusSub = monitor.statusStream.listen((status) {
      if (status == NetworkStatus.online) _replayAll();
    });
  }

  /// Number of pending requests.
  int get pendingCount => _queue.length;

  /// Stream of queue events.
  Stream<OfflineQueueEvent> get events => _eventController.stream;

  /// Queue a request for later replay.
  ///
  /// Only mutating methods are queued. GET requests are ignored.
  bool enqueue(AnyLinkRequest request, {Duration? ttl}) {
    if (!_mutatingMethods.contains(request.method.toUpperCase())) return false;
    if (_queue.length >= maxQueueSize) return false;

    final queued = QueuedRequest(
      request: request,
      ttl: ttl ?? defaultTtl,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _queue.add(queued);
    _eventController.add(OfflineQueueEvent(type: 'queued', request: queued));
    return true;
  }

  Future<void> _replayAll() async {
    final toReplay = List<QueuedRequest>.from(_queue);
    _queue.clear();

    for (final item in toReplay) {
      if (item.isExpired) {
        _eventController.add(OfflineQueueEvent(type: 'expired', request: item));
        continue;
      }
      try {
        _eventController.add(OfflineQueueEvent(type: 'replaying', request: item));
        final response = await client.request(item.request);
        _eventController.add(OfflineQueueEvent(type: 'replayed', request: item, response: response));
      } on AnyLinkError catch (e) {
        _eventController.add(OfflineQueueEvent(type: 'failed', request: item, error: e));
      }
    }
  }

  void dispose() {
    _statusSub.cancel();
    _eventController.close();
  }
}
