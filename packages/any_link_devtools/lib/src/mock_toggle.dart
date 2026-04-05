import 'package:any_link/any_link.dart';

/// Switches between real API responses and mock responses at runtime.
///
/// No app restart needed. Useful for QA testing error scenarios.
///
/// ```dart
/// final toggle = MockToggle();
/// toggle.mock('/orders', {'error': 'Server error'}, statusCode: 500);
/// toggle.enable(); // All registered paths return mocked responses.
///
/// client.interceptors.add(toggle.interceptor);
/// ```
class MockToggle {
  bool _enabled = false;
  final Map<String, _MockEntry> _mocks = {};

  bool get isEnabled => _enabled;

  void enable() => _enabled = true;
  void disable() => _enabled = false;
  void toggle() => _enabled = !_enabled;

  /// Register a mock response for [path].
  void mock(String path, dynamic body, {int statusCode = 200}) {
    _mocks[path] = _MockEntry(body: body, statusCode: statusCode);
  }

  void removeMock(String path) => _mocks.remove(path);
  void clearMocks() => _mocks.clear();

  AnyLinkInterceptor get interceptor => _MockToggleInterceptor(this);
}

class _MockEntry {
  final dynamic body;
  final int statusCode;
  _MockEntry({required this.body, required this.statusCode});
}

class _MockToggleInterceptor extends AnyLinkInterceptor {
  final MockToggle toggle;
  _MockToggleInterceptor(this.toggle);

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    if (!toggle._enabled) return request;
    final mock = toggle._mocks[request.path];
    if (mock == null) return request;

    // Signal via extra that this request should be mocked.
    return request.copyWith(
      extra: {...?request.extra, '_mock': mock},
    );
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async => response;

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async => error;
}
