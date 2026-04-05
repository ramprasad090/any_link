import '../page_info.dart';
import 'pagination_parser.dart';

/// Parses generic cursor-based pagination:
/// ```json
/// { "data": [...], "pagination": { "next_cursor": "abc123", "has_more": true } }
/// ```
class CursorPaginationParser extends PaginationParser {
  final String dataKey;
  final String paginationKey;
  final String nextCursorKey;
  final String hasMoreKey;

  const CursorPaginationParser({
    this.dataKey = 'data',
    this.paginationKey = 'pagination',
    this.nextCursorKey = 'next_cursor',
    this.hasMoreKey = 'has_more',
  });

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final map = json as Map<String, dynamic>;
    final data = map[dataKey] as List? ?? [];
    final pagination = map[paginationKey] as Map<String, dynamic>? ?? {};

    final items = data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    final nextCursor = pagination[nextCursorKey] as String?;
    final hasMore = pagination[hasMoreKey] as bool? ?? nextCursor != null;

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: currentPage,
        pageSize: items.length,
        hasNextPage: hasMore,
        nextCursor: nextCursor,
      ),
    );
  }
}
