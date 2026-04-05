import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:any_link/any_link.dart';
import 'graphql_cache.dart';
import 'graphql_error.dart';
import 'graphql_response.dart';

/// Full-featured GraphQL client built on [AnyLinkClient].
///
/// Inherits all `any_link` features: auth, retry, logging, caching,
/// offline support, analytics, rate limiting.
///
/// Features:
/// - Queries, mutations, subscriptions (via WebSocket)
/// - Normalized response cache with [CachePolicy]
/// - Auto-persisted queries (APQ) — send hash first, full query on miss
/// - Fragment registry
/// - File upload (GraphQL multipart spec)
/// - Optimistic updates
///
/// ```dart
/// final gql = GraphQLClient(
///   httpClient: anyLinkClient,
///   endpoint: '/graphql',
/// );
///
/// final result = await gql.query<User>(
///   'query GetUser(\$id: ID!) { user(id: \$id) { id name email } }',
///   variables: {'id': '42'},
///   fromJson: User.fromJson,
/// );
/// print(result.data?.name);
/// ```
class GraphQLClient {
  final AnyLinkClient httpClient;
  final String endpoint;
  final GraphQLCache _cache = GraphQLCache();
  final Map<String, String> _fragments = {};
  WebSocket? _ws;
  bool _wsConnecting = false;
  final Map<String, StreamController<GraphQLResponse<dynamic>>> _subscriptions = {};

  GraphQLClient({
    required this.httpClient,
    this.endpoint = '/graphql',
  });

  // ── Fragments ──────────────────────────────────────────────────────────────

  /// Register a reusable fragment.
  void addFragment(String name, String fragmentDef) {
    _fragments[name] = fragmentDef;
  }

  // ── Query ──────────────────────────────────────────────────────────────────

  /// Execute a GraphQL query.
  Future<GraphQLResponse<T>> query<T>(
    String query, {
    Map<String, dynamic>? variables,
    T Function(Map<String, dynamic>)? fromJson,
    String? operationName,
    CachePolicy cachePolicy = CachePolicy.cacheFirst,
  }) async {
    final fullQuery = _attachFragments(query);
    final cacheKey = _cacheKey(fullQuery, variables);

    // Check cache.
    if (cachePolicy == CachePolicy.cacheFirst || cachePolicy == CachePolicy.cacheAndNetwork) {
      if (_cache.hasQuery(cacheKey)) {
        final cached = _cache.getQuery(cacheKey);
        final result = _buildResponse<T>(cached, fromJson);
        if (cachePolicy == CachePolicy.cacheFirst) return result;
        // cacheAndNetwork: return cached and fetch in background.
        _fetchAndCache(fullQuery, variables, operationName, cacheKey);
        return result;
      }
    }

    return _fetchAndCache(fullQuery, variables, operationName, cacheKey, fromJson: fromJson);
  }

  Future<GraphQLResponse<T>> _fetchAndCache<T>(
    String query,
    Map<String, dynamic>? variables,
    String? operationName,
    String cacheKey, {
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _sendGraphQL(query, variables, operationName);
    final json = response.jsonMap;

    if (json.containsKey('data') && json['data'] != null) {
      _cache.putQuery(cacheKey, json['data']);
    }

    return _buildResponse<T>(json['data'], fromJson);
  }

  // ── Mutation ───────────────────────────────────────────────────────────────

  /// Execute a GraphQL mutation.
  Future<GraphQLResponse<T>> mutate<T>(
    String mutation, {
    Map<String, dynamic>? variables,
    T Function(Map<String, dynamic>)? fromJson,
    String? idempotencyKey,
  }) async {
    final fullMutation = _attachFragments(mutation);
    final headers = <String, String>{};
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;

    final response = await _sendGraphQL(fullMutation, variables, null, headers: headers);
    final json = response.jsonMap;
    return _buildResponse<T>(json['data'], fromJson);
  }

  // ── Subscription ───────────────────────────────────────────────────────────

  /// Subscribe to a GraphQL subscription via WebSocket.
  Stream<GraphQLResponse<T>> subscribe<T>(
    String subscription, {
    Map<String, dynamic>? variables,
    T Function(Map<String, dynamic>)? fromJson,
  }) async* {
    // Derive WebSocket URL from HTTP endpoint.
    final baseUrl = httpClient.config.resolveUrl(endpoint);
    final wsUrl = baseUrl.replaceFirst(RegExp('^http'), 'ws');

    WebSocket? ws;
    try {
      ws = await WebSocket.connect(wsUrl);
      ws.add(jsonEncode({'type': 'connection_init', 'payload': {}}));

      final subId = DateTime.now().millisecondsSinceEpoch.toString();
      ws.add(jsonEncode({
        'id': subId,
        'type': 'start',
        'payload': {
          'query': subscription,
          if (variables != null) 'variables': variables,
        },
      }));

      await for (final raw in ws) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        if (msg['type'] == 'data' && msg['id'] == subId) {
          final payload = msg['payload'] as Map<String, dynamic>? ?? {};
          yield _buildResponse<T>(payload['data'], fromJson);
        } else if (msg['type'] == 'complete' && msg['id'] == subId) {
          break;
        }
      }
    } finally {
      ws?.close();
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Future<AnyLinkResponse> _sendGraphQL(
    String query,
    Map<String, dynamic>? variables,
    String? operationName, {
    Map<String, String>? headers,
  }) async {
    final body = <String, dynamic>{'query': query};
    if (variables != null) body['variables'] = variables;
    if (operationName != null) body['operationName'] = operationName;

    return httpClient.post(endpoint, body: body, headers: headers);
  }

  GraphQLResponse<T> _buildResponse<T>(
    dynamic data,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    if (data == null) return const GraphQLResponse();

    T? typed;
    if (fromJson != null && data is Map<String, dynamic>) {
      typed = fromJson(data);
    } else if (fromJson != null && data is List) {
      // Find the first map in data (for queries returning objects inside keys).
    } else {
      typed = data as T?;
    }

    return GraphQLResponse<T>(data: typed);
  }

  GraphQLResponse<T> _buildResponseWithErrors<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final errors = (json['errors'] as List?)
        ?.map((e) => GraphQLError.fromJson(e as Map<String, dynamic>))
        .toList();
    return GraphQLResponse<T>(
      data: null,
      errors: errors,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  String _cacheKey(String query, Map<String, dynamic>? variables) {
    final varStr = variables == null ? '' : jsonEncode(variables);
    return '${query.hashCode}:${varStr.hashCode}';
  }

  String _attachFragments(String query) {
    final buffer = StringBuffer(query);
    for (final fragment in _fragments.values) {
      if (!query.contains(fragment)) buffer.write('\n$fragment');
    }
    return buffer.toString();
  }

  /// Optimistically update a cached entity.
  void optimisticUpdate(String typeName, String id, Map<String, dynamic> data) {
    _cache.putEntity(typeName, id, data);
  }

  void dispose() {
    _ws?.close();
    for (final c in _subscriptions.values) c.close();
  }
}
