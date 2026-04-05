import '../page_info.dart';
import 'pagination_parser.dart';

/// Parses Strapi v4 pagination response:
/// ```json
/// {
///   "data": [...],
///   "meta": { "pagination": { "page": 1, "pageSize": 25, "pageCount": 4, "total": 100 } }
/// }
/// ```
class StrapiPaginationParser extends PaginationParser {
  const StrapiPaginationParser();

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final map = json as Map<String, dynamic>;
    final data = map['data'] as List? ?? [];
    final meta = map['meta'] as Map<String, dynamic>? ?? {};
    final pagination = meta['pagination'] as Map<String, dynamic>? ?? {};

    final items = data.map((e) {
      final item = e as Map<String, dynamic>;
      // Strapi wraps items as {id, attributes}
      final attributes = item['attributes'] as Map<String, dynamic>? ?? item;
      return fromJson({...attributes, 'id': item['id']});
    }).toList();

    final page = pagination['page'] as int? ?? currentPage;
    final pageCount = pagination['pageCount'] as int? ?? 1;
    final pageSize = pagination['pageSize'] as int? ?? items.length;
    final total = pagination['total'] as int?;

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: page,
        totalPages: pageCount,
        totalItems: total,
        pageSize: pageSize,
        hasNextPage: page < pageCount,
        hasPreviousPage: page > 1,
      ),
    );
  }
}
