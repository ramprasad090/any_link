/// Sealed hierarchy of pagination strategies supported by [Paginator].
sealed class PaginationStrategy {
  const PaginationStrategy();
}

/// Classic page-number pagination. Adds `?page=N&per_page=M` to the URL.
final class PageNumberStrategy extends PaginationStrategy {
  final String pageParam;
  final String perPageParam;
  final int perPage;
  final int startPage;

  const PageNumberStrategy({
    this.pageParam = 'page',
    this.perPageParam = 'per_page',
    this.perPage = 15,
    this.startPage = 1,
  });
}

/// Cursor-based pagination. Adds `?cursor=<token>&limit=N`.
final class CursorStrategy extends PaginationStrategy {
  final String cursorParam;
  final String limitParam;
  final int limit;

  const CursorStrategy({
    this.cursorParam = 'cursor',
    this.limitParam = 'limit',
    this.limit = 15,
  });
}

/// Offset/limit pagination. Adds `?offset=N&limit=M`.
final class OffsetLimitStrategy extends PaginationStrategy {
  final String offsetParam;
  final String limitParam;
  final int limit;

  const OffsetLimitStrategy({
    this.offsetParam = 'offset',
    this.limitParam = 'limit',
    this.limit = 15,
  });
}

/// Seek / keyset pagination. Uses `after` or `since` with a value extracted
/// from the last item in the previous page.
final class SeekStrategy extends PaginationStrategy {
  final String afterParam;
  final int limit;

  /// Extracts the seek value from the last loaded item.
  final dynamic Function(dynamic lastItem) extractSeekValue;

  const SeekStrategy({
    this.afterParam = 'after',
    this.limit = 15,
    required this.extractSeekValue,
  });
}
