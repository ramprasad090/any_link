import 'package:flutter/material.dart';
import '../paginator.dart';
import '../pagination_state.dart';

/// A [SliverList] variant of the paginator widget, composable in [CustomScrollView].
class AnyLinkPaginatedSliver<T> extends StatefulWidget {
  final Paginator<T> paginator;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? loadingWidget;

  const AnyLinkPaginatedSliver({
    super.key,
    required this.paginator,
    required this.itemBuilder,
    this.loadingWidget,
  });

  @override
  State<AnyLinkPaginatedSliver<T>> createState() => _AnyLinkPaginatedSliverState<T>();
}

class _AnyLinkPaginatedSliverState<T> extends State<AnyLinkPaginatedSliver<T>> {
  @override
  void initState() {
    super.initState();
    widget.paginator.loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PaginatedState<T>>(
      valueListenable: widget.paginator.state,
      builder: (context, state, _) {
        final items = switch (state) {
          PaginatedLoaded(:final items) => items,
          PaginatedLoading(:final existingItems) => existingItems,
          PaginatedError(:final existingItems) => existingItems,
          _ => <T>[],
        };
        final isLoadingMore = state is PaginatedLoading<T> && !(state).isFirstPage;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == items.length && isLoadingMore) {
                return Center(
                  child: widget.loadingWidget ??
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                );
              }
              if (index >= items.length) return null;
              return widget.itemBuilder(context, items[index]);
            },
            childCount: items.length + (isLoadingMore ? 1 : 0),
          ),
        );
      },
    );
  }
}
