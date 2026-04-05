import '../page_info.dart';
import 'pagination_parser.dart';

/// Fully custom pagination parser.
///
/// Provide callbacks for each piece of metadata. Works with any backend.
///
/// ```dart
/// CustomPaginationParser(
///   extractItems: (json) => json['rows'] as List,
///   extractHasMore: (json) => json['has_more'] as bool,
///   extractCurrentPage: (json) => json['page'] as int,
///   extractTotalItems: (json) => json['total'] as int?,
/// )
/// ```
class CustomPaginationParser extends PaginationParser {
  final List Function(dynamic json) extractItems;
  final bool Function(dynamic json) extractHasMore;
  final int Function(dynamic json)? extractCurrentPage;
  final int? Function(dynamic json)? extractTotalItems;
  final int? Function(dynamic json)? extractTotalPages;
  final String? Function(dynamic json)? extractNextCursor;
  final int pageSize;

  const CustomPaginationParser({
    required this.extractItems,
    required this.extractHasMore,
    this.extractCurrentPage,
    this.extractTotalItems,
    this.extractTotalPages,
    this.extractNextCursor,
    this.pageSize = 15,
  });

  @override
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  ) {
    final rawItems = extractItems(json);
    final items = rawItems.map((e) => fromJson(e as Map<String, dynamic>)).toList();

    return ParsedPage(
      items: items,
      pageInfo: PageInfo(
        currentPage: extractCurrentPage?.call(json) ?? currentPage,
        totalItems: extractTotalItems?.call(json),
        totalPages: extractTotalPages?.call(json),
        pageSize: pageSize,
        hasNextPage: extractHasMore(json),
        nextCursor: extractNextCursor?.call(json),
      ),
    );
  }
}
