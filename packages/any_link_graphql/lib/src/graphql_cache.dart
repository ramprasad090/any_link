import 'dart:collection';

/// Cache policy for GraphQL operations.
enum CachePolicy {
  /// Return cached data if available; fetch only if missing.
  cacheFirst,

  /// Always fetch; cache the result.
  networkFirst,

  /// Return cached data AND fetch in background to update.
  cacheAndNetwork,

  /// Always fetch; never read or write cache.
  networkOnly,
}

/// Normalized entity cache for GraphQL.
///
/// Stores entities by `__typename:id`. When any query returns an entity,
/// all queries displaying that entity auto-update.
class GraphQLCache {
  final Map<String, Map<String, dynamic>> _entities = {};
  final LinkedHashMap<String, dynamic> _queryCache = LinkedHashMap();
  static const int _maxQueryEntries = 100;

  // ── Query cache ────────────────────────────────────────────────────────────

  void putQuery(String key, dynamic data) {
    if (_queryCache.length >= _maxQueryEntries) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[key] = data;
    _normalizeAndStore(data);
  }

  dynamic getQuery(String key) => _queryCache[key];
  bool hasQuery(String key) => _queryCache.containsKey(key);
  void invalidateQuery(String key) => _queryCache.remove(key);
  void clear() {
    _queryCache.clear();
    _entities.clear();
  }

  // ── Normalized entity store ────────────────────────────────────────────────

  void putEntity(String typeName, String id, Map<String, dynamic> data) {
    _entities['$typeName:$id'] = data;
  }

  Map<String, dynamic>? getEntity(String typeName, String id) =>
      _entities['$typeName:$id'];

  void _normalizeAndStore(dynamic data) {
    if (data is Map<String, dynamic>) {
      final typeName = data['__typename'] as String?;
      final id = data['id']?.toString();
      if (typeName != null && id != null) {
        putEntity(typeName, id, Map<String, dynamic>.from(data));
      }
      for (final value in data.values) {
        _normalizeAndStore(value);
      }
    } else if (data is List) {
      for (final item in data) {
        _normalizeAndStore(item);
      }
    }
  }
}
