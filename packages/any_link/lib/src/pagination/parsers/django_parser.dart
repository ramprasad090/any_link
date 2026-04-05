import '../page_info.dart';
import 'pagination_parser.dart';

/// Parses Django REST Framework's pagination response:
/// ```json
/// { "count": 100, "next": "...", "previous": null, "results": [...] }
/// ```
class DjangoPaginationParser extends PaginationParser {
  final int pageSize;
  const DjangoPaginationParser({this.pageSize = 15});

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final map = json as Map<String, dynamic>;
    final results = map['results'] as List? ?? [];
    final count = map['count'] as int? ?? results.length;
    final hasNext = map['next'] != null;

    final items = results.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    final totalPages = (count / pageSize).ceil();

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: currentPage,
        totalPages: totalPages,
        totalItems: count,
        pageSize: pageSize,
        hasNextPage: hasNext,
        hasPreviousPage: map['previous'] != null,
      ),
    );
  }
}
