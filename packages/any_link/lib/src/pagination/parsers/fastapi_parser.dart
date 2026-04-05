import '../page_info.dart';
import 'pagination_parser.dart';

/// Parses FastAPI pagination response:
/// ```json
/// { "items": [...], "total": 100, "page": 1, "pages": 7, "size": 15 }
/// ```
class FastApiPaginationParser extends PaginationParser {
  const FastApiPaginationParser();

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final map = json as Map<String, dynamic>;
    final items = (map['items'] as List? ?? [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
    final total = map['total'] as int? ?? items.length;
    final page = map['page'] as int? ?? currentPage;
    final pages = map['pages'] as int? ?? 1;
    final size = map['size'] as int? ?? items.length;

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: page,
        totalPages: pages,
        totalItems: total,
        pageSize: size,
        hasNextPage: page < pages,
        hasPreviousPage: page > 1,
      ),
    );
  }
}
