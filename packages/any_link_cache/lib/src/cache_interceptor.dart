import 'package:any_link/any_link.dart';
import 'cache_strategy.dart';
import 'response_cache.dart';

/// Adds caching to [AnyLinkClient].
///
/// Respects `Cache-Control`, `ETag`, and `Last-Modified` headers.
/// Sends `If-None-Match` / `If-Modified-Since` on repeat requests → server
/// returns 304 → zero bytes transferred.
///
/// ```dart
/// client.interceptors.add(CacheInterceptor(
///   strategy: CacheStrategy.staleWhileRevalidate,
///   defaultTtl: Duration(minutes: 5),
/// ));
/// ```
class CacheInterceptor extends AnyLinkInterceptor {
  final CacheStrategy strategy;
  final Duration defaultTtl;
  final ResponseCache _cache;

  // ETag/Last-Modified store.
  final Map<String, String> _etags = {};
  final Map<String, String> _lastModified = {};

  CacheInterceptor({
    this.strategy = CacheStrategy.staleWhileRevalidate,
    this.defaultTtl = const Duration(minutes: 5),
    int maxEntries = 200,
  }) : _cache = ResponseCache(maxEntries: maxEntries, defaultTtl: defaultTtl);

  @override
  Future<AnyLinkRequest> onRequest(AnyLinkRequest request) async {
    // Only cache GET requests.
    if (request.method.toUpperCase() != 'GET') return request;

    final key = _key(request);
    final cached = _cache.get(key);
    final etag = _etags[key];
    final lastMod = _lastModified[key];

    // Build conditional headers.
    final conditionalHeaders = <String, String>{...?request.headers};
    if (etag != null) conditionalHeaders['If-None-Match'] = etag;
    if (lastMod != null) conditionalHeaders['If-Modified-Since'] = lastMod;

    if (strategy == CacheStrategy.cacheFirst && cached != null) {
      // Return cached immediately — the client will see this via a resolved error below.
      // We store the cached response in extra to short-circuit the network call.
      return request.copyWith(
        headers: conditionalHeaders,
        extra: {...?request.extra, '_cached_response': cached},
      );
    }

    return request.copyWith(headers: conditionalHeaders);
  }

  @override
  Future<AnyLinkResponse> onResponse(AnyLinkResponse response) async {
    // 304 Not Modified — serve from cache.
    if (response.statusCode == 304) {
      final cached = _cache.get(_responseKey(response));
      if (cached != null) return cached;
    }

    // Cache successful GET responses.
    if (response.requestMethod.toUpperCase() == 'GET' && response.isSuccess) {
      final key = _responseKey(response);
      final ttl = _parseCacheControl(response.headers['cache-control']) ?? defaultTtl;
      _cache.put(key, response, ttl: ttl);

      if (response.etag != null) _etags[key] = response.etag!;
      if (response.lastModified != null) _lastModified[key] = response.lastModified!;
    }

    return response;
  }

  @override
  Future<AnyLinkError> onError(AnyLinkError error) async {
    // If offline, serve stale cache entry if available.
    if (error.isNetworkError && error.requestPath != null) {
      final cached = _cache.get(_errorKey(error));
      if (cached != null) {
        return error.copyWith(resolved: true, resolvedResponse: cached);
      }
    }
    return error;
  }

  Duration? _parseCacheControl(String? header) {
    if (header == null) return null;
    final match = RegExp(r'max-age=(\d+)').firstMatch(header);
    if (match == null) return null;
    return Duration(seconds: int.parse(match.group(1)!));
  }

  String _key(AnyLinkRequest r) => '${r.method}:${r.path}';
  String _responseKey(AnyLinkResponse r) => '${r.requestMethod}:${r.requestPath}';
  String _errorKey(AnyLinkError e) => '${e.requestMethod}:${e.requestPath}';
}
