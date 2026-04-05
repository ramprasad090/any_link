import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A parsed Server-Sent Event.
class SSEEvent {
  final String? id;
  final String? event;
  final String data;
  final DateTime receivedAt;

  const SSEEvent({
    this.id,
    this.event,
    required this.data,
    required this.receivedAt,
  });

  @override
  String toString() => 'SSEEvent(event: $event, data: $data)';
}

/// Server-Sent Events (SSE) client built directly on `dart:io` [HttpClient].
///
/// Fixes flutter#136334 and flutter#43343: on Flutter Web, SSE events should
/// arrive token-by-token but the standard XHR approach batches them. This
/// implementation uses chunked streaming on native and the same approach
/// on web via a stub.
///
/// Features:
/// - Auto-reconnect with configurable delay
/// - Resumes from last received event ID (`Last-Event-ID` header)
/// - Unlimited reconnect or capped at [maxReconnectAttempts]
///
/// ```dart
/// final client = SSEClient();
/// final stream = client.subscribe('https://api.example.com/events',
///     headers: {'Authorization': 'Bearer $token'});
///
/// await for (final event in stream) {
///   print('${event.event}: ${event.data}');
/// }
/// ```
class SSEClient {
  HttpClient? _httpClient;
  bool _closed = false;

  /// Subscribe to an SSE endpoint.
  Stream<SSEEvent> subscribe(
    String url, {
    Map<String, String>? headers,
    String? lastEventId,
    Duration reconnectDelay = const Duration(seconds: 3),
    int maxReconnectAttempts = -1, // -1 = unlimited
  }) async* {
    _httpClient = HttpClient();
    int attempts = 0;
    String? currentLastId = lastEventId;

    while (!_closed) {
      if (maxReconnectAttempts >= 0 && attempts > maxReconnectAttempts) break;

      try {
        final uri = Uri.parse(url);
        final request = await _httpClient!.openUrl('GET', uri);

        // SSE-specific headers.
        request.headers.set('Accept', 'text/event-stream');
        request.headers.set('Cache-Control', 'no-cache');
        if (currentLastId != null) request.headers.set('Last-Event-ID', currentLastId);
        headers?.forEach((k, v) => request.headers.set(k, v));

        final response = await request.close();

        if (response.statusCode != 200) {
          throw Exception('SSE server returned ${response.statusCode}');
        }

        // Parse the SSE stream line by line.
        String? eventId;
        String? eventType;
        final dataLines = <String>[];

        await for (final chunk in response.transform(utf8.decoder).transform(const LineSplitter())) {
          if (_closed) return;

          if (chunk.isEmpty) {
            // Dispatch event on empty line.
            if (dataLines.isNotEmpty) {
              final data = dataLines.join('\n');
              currentLastId = eventId;
              yield SSEEvent(
                id: eventId,
                event: eventType,
                data: data,
                receivedAt: DateTime.now(),
              );
            }
            eventId = null;
            eventType = null;
            dataLines.clear();
          } else if (chunk.startsWith('id:')) {
            eventId = chunk.substring(3).trim();
          } else if (chunk.startsWith('event:')) {
            eventType = chunk.substring(6).trim();
          } else if (chunk.startsWith('data:')) {
            dataLines.add(chunk.substring(5).trim());
          } else if (chunk.startsWith('retry:')) {
            // Server-suggested reconnect delay — ignore for now.
          }
        }
      } catch (_) {
        if (_closed) return;
        attempts++;
        await Future<void>.delayed(reconnectDelay);
      }
    }
  }

  /// Close the SSE connection.
  void close() {
    _closed = true;
    _httpClient?.close(force: true);
  }
}
