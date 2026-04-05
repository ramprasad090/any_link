import 'dart:collection';
import 'package:any_link/any_link.dart';

/// A single cache entry.
class _CacheEntry {
  final AnyLinkResponse response;
  final DateTime cachedAt;
  final Duration ttl;

  _CacheEntry({required this.response, required this.ttl})
      : cachedAt = DateTime.now();

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
}

/// In-memory LRU response cache.
class ResponseCache {
  final int maxEntries;
  final Duration defaultTtl;

  final LinkedHashMap<String, _CacheEntry> _store = LinkedHashMap();

  ResponseCache({
    this.maxEntries = 200,
    this.defaultTtl = const Duration(minutes: 5),
  });

  /// Store [response] under [key].
  void put(String key, AnyLinkResponse response, {Duration? ttl}) {
    if (_store.length >= maxEntries) {
      _store.remove(_store.keys.first); // evict LRU
    }
    _store[key] = _CacheEntry(response: response, ttl: ttl ?? defaultTtl);
  }

  /// Retrieve a non-expired entry, or null.
  AnyLinkResponse? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }
    // Move to end (LRU).
    _store.remove(key);
    _store[key] = entry;
    return entry.response;
  }

  /// Whether [key] is in the cache (possibly expired).
  bool has(String key) => _store.containsKey(key);

  /// Remove [key].
  void invalidate(String key) => _store.remove(key);

  /// Clear all entries.
  void clear() => _store.clear();

  int get size => _store.length;
}
