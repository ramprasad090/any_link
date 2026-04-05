import '../page_info.dart';
import 'pagination_parser.dart';

/// Parses Laravel's default pagination response format:
/// ```json
/// {
///   "data": [...],
///   "links": { "next": "...", "prev": "..." },
///   "meta": { "current_page": 1, "last_page": 5, "per_page": 15, "total": 72 }
/// }
/// ```
class LaravelPaginationParser extends PaginationParser {
  const LaravelPaginationParser();

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final map = json as Map<String, dynamic>;
    final data = map['data'] as List? ?? [];
    final meta = map['meta'] as Map<String, dynamic>? ?? {};
    final links = map['links'] as Map<String, dynamic>? ?? {};

    final items = data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    final lastPage = meta['last_page'] as int? ?? 1;
    final perPage = meta['per_page'] as int? ?? items.length;
    final total = meta['total'] as int?;
    final hasNext = links['next'] != null;

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: meta['current_page'] as int? ?? currentPage,
        totalPages: lastPage,
        totalItems: total,
        pageSize: perPage,
        hasNextPage: hasNext,
        hasPreviousPage: (meta['current_page'] as int? ?? 1) > 1,
      ),
    );
  }
}
