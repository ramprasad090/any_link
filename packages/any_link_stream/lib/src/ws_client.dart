import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A WebSocket message.
class WSMessage {
  final dynamic data;
  final bool isText;
  final DateTime receivedAt;

  const WSMessage({required this.data, required this.isText, required this.receivedAt});

  Map<String, dynamic>? get jsonMap => isText ? jsonDecode(data as String) as Map<String, dynamic> : null;
}

/// WebSocket client with auto-reconnect, heartbeat ping/pong, and
/// message queuing during disconnects.
///
/// ```dart
/// final ws = WSClient();
/// final stream = ws.connect('wss://api.example.com/ws');
///
/// stream.listen((msg) => print(msg.data));
/// ws.sendJson({'type': 'subscribe', 'channel': 'orders'});
/// ```
class WSClient {
  WebSocket? _ws;
  bool _closed = false;
  final List<dynamic> _queue = [];

  bool get isConnected => _ws != null && _ws!.readyState == WebSocket.open;

  /// Connect to [url] and return a stream of incoming messages.
  Stream<WSMessage> connect(
    String url, {
    Map<String, String>? headers,
    Duration pingInterval = const Duration(seconds: 30),
    int maxReconnectAttempts = 5,
    Duration reconnectDelay = const Duration(seconds: 3),
  }) async* {
    int attempts = 0;

    while (!_closed && (maxReconnectAttempts < 0 || attempts <= maxReconnectAttempts)) {
      try {
        _ws = await WebSocket.connect(url, headers: headers);
        attempts = 0;

        // Flush queued messages.
        for (final msg in _queue) {
          _ws!.add(msg);
        }
        _queue.clear();

        // Set up ping.
        Timer? pingTimer;
        pingTimer = Timer.periodic(pingInterval, (_) {
          if (isConnected) _ws!.add('ping');
        });

        await for (final data in _ws!) {
          if (_closed) {
            pingTimer.cancel();
            return;
          }
          yield WSMessage(
            data: data,
            isText: data is String,
            receivedAt: DateTime.now(),
          );
        }
        pingTimer.cancel();
      } catch (_) {
        if (_closed) return;
        attempts++;
        _ws = null;
        await Future<void>.delayed(reconnectDelay);
      }
    }
  }

  /// Send a raw [data] payload (String or List<int>).
  void send(dynamic data) {
    if (isConnected) {
      _ws!.add(data);
    } else {
      _queue.add(data);
    }
  }

  /// Encode [data] as JSON and send it.
  void sendJson(Map<String, dynamic> data) => send(jsonEncode(data));

  /// Close the WebSocket connection.
  void close() {
    _closed = true;
    _ws?.close();
  }
}
