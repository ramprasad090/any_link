import 'package:flutter/material.dart';
import '../paginator.dart';
import '../pagination_state.dart';

/// A drop-in infinite-scroll [ListView] backed by a [Paginator].
///
/// ```dart
/// AnyLinkPaginatedList<Order>(
///   paginator: orderPaginator,
///   itemBuilder: (context, order) => OrderCard(order: order),
///   loadingWidget: const CircularProgressIndicator(),
/// )
/// ```
class AnyLinkPaginatedList<T> extends StatefulWidget {
  final Paginator<T> paginator;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget Function(Object error)? errorBuilder;
  final Widget? footerLoadingWidget;
  final ScrollController? scrollController;
  final double loadMoreThreshold;
  final EdgeInsetsGeometry? padding;

  const AnyLinkPaginatedList({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.loadingWidget,
    this.emptyWidget,
    this.errorBuilder,
    this.footerLoadingWidget,
    this.scrollController,
    this.loadMoreThreshold = 200.0,
    this.padding,
  });

  @override
  State<AnyLinkPaginatedList<T>> createState() => _AnyLinkPaginatedListState<T>();
}

class _AnyLinkPaginatedListState<T> extends State<AnyLinkPaginatedList<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
    widget.paginator.loadInitial();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - widget.loadMoreThreshold) {
      widget.paginator.loadNext();
    }
  }

  @override
  void dispose() {
    if (widget.scrollController == null) _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaginatedState<T>>(
      valueListenable: widget.paginator.state,
      builder: (context, state, _) {
        return switch (state) {
          PaginatedInitial() => const SizedBox.shrink(),
          PaginatedLoading(isFirstPage: true) =>
            Center(child: widget.loadingWidget ?? const CircularProgressIndicator()),
          PaginatedLoading(:final existingItems) => _buildList(existingItems, isLoadingMore: true),
          PaginatedLoaded(:final items) => items.isEmpty
              ? (widget.emptyWidget ?? const Center(child: Text('No items found')))
              : _buildList(items),
          PaginatedError(error: final err, existingItems: final existing) when existing.isEmpty =>
            widget.errorBuilder?.call(err) ??
                Center(child: Text(err.message, style: const TextStyle(color: Colors.red))),
          PaginatedError(:final existingItems) => _buildList(existingItems),
        };
      },
    );
  }

  Widget _buildList(List<T> items, {bool isLoadingMore = false}) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: items.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return Center(
            child: widget.footerLoadingWidget ??
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
          );
        }
        return widget.itemBuilder(context, items[index]);
      },
    );
  }
}
