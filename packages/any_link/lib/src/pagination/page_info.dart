/// Metadata about the current pagination state.
class PageInfo {
  final int currentPage;
  final int? totalPages;
  final int? totalItems;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final String? nextCursor;
  final String? previousCursor;
  final int? nextOffset;

  const PageInfo({
    required this.currentPage,
    required this.pageSize,
    required this.hasNextPage,
    this.totalPages,
    this.totalItems,
    this.hasPreviousPage = false,
    this.nextCursor,
    this.previousCursor,
    this.nextOffset,
  });

  @override
  String toString() =>
      'PageInfo(page: $currentPage/${totalPages ?? "?"}, '
      'items: ${totalItems ?? "?"}, hasNext: $hasNextPage)';
}
