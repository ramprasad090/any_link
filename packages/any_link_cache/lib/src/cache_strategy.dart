/// Controls when to use cached data vs fetch from network.
enum CacheStrategy {
  /// Return cached data immediately; fetch in background to update cache.
  /// User always sees something instantly (no spinner on repeat visits).
  staleWhileRevalidate,

  /// Return cached data if fresh; fetch only if expired.
  cacheFirst,

  /// Always fetch; cache the result for next time.
  networkFirst,

  /// Never use cache.
  networkOnly,

  /// Only use cache; fail if not cached.
  cacheOnly,
}
