import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef MockHandler = Future<MockResponse> Function(HttpRequest request);

/// A response returned by a mock handler.
class MockResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;
  final Duration delay;

  const MockResponse({
    this.statusCode = 200,
    this.body,
    this.headers = const {},
    this.delay = Duration.zero,
  });
}

/// A lightweight in-process HTTP mock server built on `dart:io`.
///
/// Use in unit tests to serve deterministic responses without any real network.
///
/// ```dart
/// final mock = AnyLinkMockServer();
/// mock.get('/users', response: MockResponse(body: {'users': []}));
/// mock.post('/login', handler: (req) async => MockResponse(body: {'token': 'test'}));
/// await mock.start(port: 0); // port 0 = OS assigns a free port
///
/// final client = AnyLinkClient(config: AnyLinkConfig(baseUrl: mock.baseUrl));
/// // ... run tests ...
/// await mock.stop();
/// ```
class AnyLinkMockServer {
  HttpServer? _server;
  final Map<String, MockHandler> _routes = {};

  /// The `http://localhost:<port>` base URL once started.
  String get baseUrl {
    assert(_server != null, 'Call start() first');
    return 'http://localhost:${_server!.port}';
  }

  /// Register a GET route with a static response.
  void get(String path, {required MockResponse response}) {
    _routes['GET:$path'] = (_) async => response;
  }

  /// Register a POST route with a static response.
  void post(String path, {MockResponse? response, MockHandler? handler}) {
    assert(response != null || handler != null);
    _routes['POST:$path'] = handler ?? ((_) async => response!);
  }

  /// Register any method route with a handler.
  void on(String method, String path, {required MockHandler handler}) {
    _routes['${method.toUpperCase()}:$path'] = handler;
  }

  /// Start the server on [port] (0 = OS chooses a free port).
  Future<void> start({int port = 0}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final key = '${request.method}:${request.uri.path}';
    final handler = _routes[key] ?? _routes['*:${request.uri.path}'];

    if (handler == null) {
      request.response.statusCode = 404;
      request.response.write('{"error":"Not found"}');
      await request.response.close();
      return;
    }

    final mock = await handler(request);
    if (mock.delay > Duration.zero) await Future<void>.delayed(mock.delay);

    request.response.statusCode = mock.statusCode;
    request.response.headers.contentType = ContentType.json;
    mock.headers.forEach((k, v) => request.response.headers.set(k, v));

    if (mock.body != null) {
      request.response.write(
        mock.body is String ? mock.body : jsonEncode(mock.body),
      );
    }
    await request.response.close();
  }

  /// Stop the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
