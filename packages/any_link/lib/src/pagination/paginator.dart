import 'dart:async';
import 'package:flutter/foundation.dart';
import '../client/any_link_client.dart';
import '../models/error.dart';
import 'pagination_state.dart';
import 'pagination_strategy.dart';
import 'parsers/pagination_parser.dart';

/// Full-featured pagination controller.
///
/// Handles page-number, cursor, offset/limit, and seek strategies.
/// Supports search, filter, sort, optimistic updates, and deduplication.
///
/// ```dart
/// final paginator = Paginator<Order>(
///   client: client,
///   endpoint: '/orders',
///   strategy: PageNumberStrategy(perPage: 20),
///   parser: LaravelPaginationParser(),
///   fromJson: Order.fromJson,
/// );
///
/// await paginator.loadInitial();
/// ```
class Paginator<T> {
  final AnyLinkClient client;
  final String endpoint;
  final PaginationStrategy strategy;
  final PaginationParser parser;
  final T Function(Map<String, dynamic>) fromJson;
  final String? idField;

  final ValueNotifier<PaginatedState<T>> state;

  List<T> _items = [];
  int _currentPage = 1;
  String? _nextCursor;
  int _nextOffset = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Map<String, dynamic> _filters = {};
  String? _searchQuery;
  String? _sortField;
  bool _sortAscending = true;
  Timer? _searchDebounce;

  Paginator({
    required this.client,
    required this.endpoint,
    required this.strategy,
    required this.parser,
    required this.fromJson,
    this.idField,
  }) : state = ValueNotifier(const PaginatedInitial());

  // ── State helpers ──────────────────────────────────────────────────────────

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  // ── Load operations ────────────────────────────────────────────────────────

  Future<void> loadInitial() async {
    _reset();
    await _load(isFirstPage: true);
  }

  Future<void> loadNext() async {
    if (_isLoading || !_hasMore) return;
    await _load(isFirstPage: false);
  }

  Future<void> loadPrevious() async {
    if (_currentPage <= 1) return;
    _currentPage--;
    await _load(isFirstPage: false);
  }

  Future<void> refresh() async {
    _reset();
    await _load(isFirstPage: true);
  }

  Future<void> jumpToPage(int page) async {
    if (strategy is! PageNumberStrategy) return;
    _currentPage = page;
    _items = [];
    await _load(isFirstPage: page == 1);
  }

  Future<void> search(String query, {Duration debounce = const Duration(milliseconds: 300)}) async {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(debounce, () async {
      _searchQuery = query.isEmpty ? null : query;
      _reset();
      await _load(isFirstPage: true);
    });
  }

  Future<void> applyFilters(Map<String, dynamic> filters) async {
    _filters = filters;
    _reset();
    await _load(isFirstPage: true);
  }

  Future<void> applySort(String field, {bool ascending = true}) async {
    _sortField = field;
    _sortAscending = ascending;
    _reset();
    await _load(isFirstPage: true);
  }

  // ── Optimistic mutations ───────────────────────────────────────────────────

  void optimisticRemove(String id) {
    if (idField == null) return;
    _items = _items.where((item) {
      final map = item as dynamic;
      return map[idField]?.toString() != id;
    }).toList();
    _notify();
  }

  void optimisticUpdate(String id, T updatedItem) {
    if (idField == null) return;
    _items = _items.map((item) {
      final map = item as dynamic;
      return map[idField]?.toString() == id ? updatedItem : item;
    }).toList();
    _notify();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _load({required bool isFirstPage}) async {
    if (_isLoading) return;
    _isLoading = true;

    state.value = PaginatedLoading<T>(
      existingItems: List.from(_items),
      isFirstPage: isFirstPage,
    );

    try {
      final params = _buildQueryParams();
      final response = await client.get(endpoint, queryParams: params);
      final parsed = parser.parse<T>(response.json, fromJson, _currentPage);

      // Dedup by idField.
      if (idField != null) {
        final existingIds = _items.map((e) => (e as dynamic)[idField]?.toString()).toSet();
        final newItems = parsed.items.where((item) {
          return !existingIds.contains((item as dynamic)[idField]?.toString());
        }).toList();
        _items = isFirstPage ? parsed.items : [..._items, ...newItems];
      } else {
        _items = isFirstPage ? parsed.items : [..._items, ...parsed.items];
      }

      _hasMore = parsed.pageInfo.hasNextPage;
      _nextCursor = parsed.pageInfo.nextCursor;
      _nextOffset += parsed.items.length;

      if (strategy is PageNumberStrategy) {
        _currentPage = parsed.pageInfo.currentPage + (isFirstPage ? 0 : 0);
        if (!isFirstPage) _currentPage++;
      }

      state.value = PaginatedLoaded<T>(
        items: List.from(_items),
        hasMore: _hasMore,
        pageInfo: parsed.pageInfo,
      );
    } on AnyLinkError catch (e) {
      state.value = PaginatedError<T>(error: e, existingItems: List.from(_items));
    } catch (e) {
      state.value = PaginatedError<T>(
        error: AnyLinkError(message: e.toString()),
        existingItems: List.from(_items),
      );
    } finally {
      _isLoading = false;
    }
  }

  Map<String, dynamic> _buildQueryParams() {
    final params = <String, dynamic>{..._filters};

    if (_searchQuery != null) params['search'] = _searchQuery!;
    if (_sortField != null) {
      params['sort'] = _sortField!;
      params['order'] = _sortAscending ? 'asc' : 'desc';
    }

    switch (strategy) {
      case PageNumberStrategy(pageParam: final pp, perPageParam: final ppp, perPage: final size, startPage: final start):
        params[pp] = _currentPage == 1 ? start : _currentPage;
        params[ppp] = size;
      case CursorStrategy(cursorParam: final cp, limitParam: final lp, limit: final size):
        if (_nextCursor != null) params[cp] = _nextCursor!;
        params[lp] = size;
      case OffsetLimitStrategy(offsetParam: final op, limitParam: final lp, limit: final size):
        params[op] = _nextOffset;
        params[lp] = size;
      case SeekStrategy(afterParam: final ap, limit: final size, extractSeekValue: final fn):
        if (_items.isNotEmpty) params[ap] = fn(_items.last);
        params['limit'] = size;
    }

    return params;
  }

  void _reset() {
    _items = [];
    _currentPage = 1;
    _nextCursor = null;
    _nextOffset = 0;
    _hasMore = true;
  }

  void _notify() {
    final current = state.value;
    if (current is PaginatedLoaded<T>) {
      state.value = PaginatedLoaded<T>(
        items: List.from(_items),
        hasMore: current.hasMore,
        pageInfo: current.pageInfo,
      );
    }
  }

  void dispose() {
    _searchDebounce?.cancel();
    state.dispose();
  }
}
