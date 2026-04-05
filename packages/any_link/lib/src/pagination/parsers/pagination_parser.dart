import '../page_info.dart';

/// Result returned by a [PaginationParser] after parsing a raw JSON response.
class ParsedPage<T> {
  final List<T> items;
  final PageInfo pageInfo;

  const ParsedPage({required this.items, required this.pageInfo});
}

/// Knows how to extract items and pagination metadata from a raw JSON response.
///
/// Implement this to support any backend pagination format.
abstract class PaginationParser {
  const PaginationParser();

  /// Parse [json] (decoded response body) into items and page metadata.
  ///
  /// [fromJson] converts each raw item map to the typed model [T].
  /// [currentPage] is the page number/cursor that was just loaded.
  ParsedPage<T> parse<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
    int currentPage,
  );
}
