import '../models/error.dart';
import 'page_info.dart';

/// Sealed state type for [Paginator]. Use pattern matching in the UI:
/// ```dart
/// switch (state) {
///   case PaginatedInitial() => const SizedBox.shrink(),
///   case PaginatedLoading(isFirstPage: true) => const CircularProgressIndicator(),
///   case PaginatedLoading(:final existingItems) => _buildListWithFooterSpinner(existingItems),
///   case PaginatedLoaded(:final items, :final hasMore) => _buildList(items, hasMore),
///   case PaginatedError(:final error, :final existingItems) => _buildError(error, existingItems),
/// }
/// ```
sealed class PaginatedState<T> {
  const PaginatedState();
}

/// Initial state before any load has started.
final class PaginatedInitial<T> extends PaginatedState<T> {
  const PaginatedInitial();
}

/// A page load is in progress.
final class PaginatedLoading<T> extends PaginatedState<T> {
  /// Items already loaded from previous pages (empty on first load).
  final List<T> existingItems;

  /// True when loading the very first page (no existing items yet).
  final bool isFirstPage;

  const PaginatedLoading({
    required this.existingItems,
    required this.isFirstPage,
  });
}

/// Page loaded successfully.
final class PaginatedLoaded<T> extends PaginatedState<T> {
  final List<T> items;
  final bool hasMore;
  final PageInfo pageInfo;

  const PaginatedLoaded({
    required this.items,
    required this.hasMore,
    required this.pageInfo,
  });
}

/// A load failed.
final class PaginatedError<T> extends PaginatedState<T> {
  final AnyLinkError error;

  /// Items already loaded before the error occurred (empty on first-page failure).
  final List<T> existingItems;

  const PaginatedError({required this.error, required this.existingItems});
}
