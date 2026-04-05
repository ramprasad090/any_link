import 'package:flutter/material.dart';
import '../paginator.dart';
import '../pagination_state.dart';

/// A drop-in infinite-scroll [GridView] backed by a [Paginator].
class AnyLinkPaginatedGrid<T> extends StatefulWidget {
  final Paginator<T> paginator;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final SliverGridDelegate gridDelegate;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget Function(Object error)? errorBuilder;
  final ScrollController? scrollController;
  final double loadMoreThreshold;
  final EdgeInsetsGeometry? padding;

  const AnyLinkPaginatedGrid({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
    this.loadingWidget,
    this.emptyWidget,
    this.errorBuilder,
    this.scrollController,
    this.loadMoreThreshold = 200.0,
    this.padding,
  });

  @override
  State<AnyLinkPaginatedGrid<T>> createState() => _AnyLinkPaginatedGridState<T>();
}

class _AnyLinkPaginatedGridState<T> extends State<AnyLinkPaginatedGrid<T>> {
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
          PaginatedLoading(:final existingItems) => _buildGrid(existingItems),
          PaginatedLoaded(:final items) => items.isEmpty
              ? (widget.emptyWidget ?? const Center(child: Text('No items found')))
              : _buildGrid(items),
          PaginatedError(error: final err, existingItems: final existing) when existing.isEmpty =>
            widget.errorBuilder?.call(err) ??
                Center(child: Text(err.message, style: const TextStyle(color: Colors.red))),
          PaginatedError(:final existingItems) => _buildGrid(existingItems),
        };
      },
    );
  }

  Widget _buildGrid(List<T> items) {
    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding,
      gridDelegate: widget.gridDelegate,
      itemCount: items.length,
      itemBuilder: (context, index) => widget.itemBuilder(context, items[index]),
    );
  }
}
