import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:any_link/any_link.dart';
import 'graphql_cache.dart';
import 'graphql_response.dart';
import 'sha256.dart';

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

  /// Enable Auto-Persisted Queries (APQ). Sends query hash first; falls back
  /// to full query on a `PersistedQueryNotFound` error.
  final bool enableApq;

  final GraphQLCache _cache = GraphQLCache();
  final Map<String, String> _fragments = {};
  final Map<String, StreamController<GraphQLResponse<dynamic>>> _subscriptions = {};
  WebSocket? _ws;

  GraphQLClient({
    required this.httpClient,
    this.endpoint = '/graphql',
    this.enableApq = false,
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

    if (cachePolicy == CachePolicy.cacheFirst ||
        cachePolicy == CachePolicy.cacheAndNetwork) {
      if (_cache.hasQuery(cacheKey)) {
        final cached = _cache.getQuery(cacheKey);
        final result = _buildResponse<T>(cached, fromJson);
        if (cachePolicy == CachePolicy.cacheFirst) return result;
        _fetchAndCache(fullQuery, variables, operationName, cacheKey);
        return result;
      }
    }

    return _fetchAndCache(fullQuery, variables, operationName, cacheKey,
        fromJson: fromJson);
  }

  Future<GraphQLResponse<T>> _fetchAndCache<T>(
    String query,
    Map<String, dynamic>? variables,
    String? operationName,
    String cacheKey, {
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = enableApq
        ? await _sendWithApq(query, variables, operationName)
        : await _sendGraphQL(query, variables, operationName);
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

    final response = await _sendGraphQL(fullMutation, variables, null,
        headers: headers);
    final json = response.jsonMap;
    return _buildResponse<T>(json['data'], fromJson);
  }

  // ── File Upload (GraphQL multipart spec) ───────────────────────────────────

  /// Upload one or more files as part of a GraphQL mutation.
  ///
  /// Follows the [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec).
  ///
  /// ```dart
  /// await gql.uploadFiles(
  ///   'mutation Upload(\$file: Upload!) { upload(file: \$file) { url } }',
  ///   variables: {'file': null},
  ///   files: [GraphQLFile(field: 'variables.file', path: '/tmp/photo.jpg')],
  /// );
  /// ```
  Future<GraphQLResponse<T>> uploadFiles<T>(
    String mutation, {
    Map<String, dynamic>? variables,
    required List<GraphQLFile> files,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final form = AnyLinkFormData();

    // operations field.
    final operations = jsonEncode({
      'query': _attachFragments(mutation),
      if (variables != null) 'variables': variables,
    });
    form.addField('operations', operations);

    // map field: maps file index → variable path.
    final map = <String, List<String>>{};
    for (var i = 0; i < files.length; i++) {
      map['$i'] = [files[i].variablePath];
    }
    form.addField('map', jsonEncode(map));

    // Attach each file.
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      form.addFile('$i', f.path, fileName: f.fileName);
    }

    final response = await httpClient.post(endpoint, body: form);
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

  // ── Auto-Persisted Queries (APQ) ───────────────────────────────────────────

  /// Send using APQ: hash-only first, full query on `PersistedQueryNotFound`.
  Future<AnyLinkResponse> _sendWithApq(
    String query,
    Map<String, dynamic>? variables,
    String? operationName,
  ) async {
    final queryHash = _sha256Hex(utf8.encode(query));

    // Phase 1: send hash only.
    final hashOnlyBody = <String, dynamic>{
      'extensions': {
        'persistedQuery': {'version': 1, 'sha256Hash': queryHash},
      },
      if (variables != null) 'variables': variables,
      if (operationName != null) 'operationName': operationName,
    };

    final hashResponse =
        await httpClient.post(endpoint, body: hashOnlyBody);
    final hashJson = hashResponse.jsonMapOrNull;

    // Check for PersistedQueryNotFound error.
    final errors = hashJson?['errors'];
    final notFound = errors is List &&
        errors.any((e) =>
            e is Map &&
            (e['extensions']?['code'] == 'PERSISTED_QUERY_NOT_FOUND' ||
                (e['message'] as String?)
                        ?.contains('PersistedQueryNotFound') ==
                    true));

    if (!notFound) return hashResponse;

    // Phase 2: send full query + hash.
    final fullBody = <String, dynamic>{
      'query': query,
      'extensions': {
        'persistedQuery': {'version': 1, 'sha256Hash': queryHash},
      },
      if (variables != null) 'variables': variables,
      if (operationName != null) 'operationName': operationName,
    };

    return httpClient.post(endpoint, body: fullBody);
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
    } else {
      typed = data as T?;
    }

    return GraphQLResponse<T>(data: typed);
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

  String _sha256Hex(List<int> data) {
    final digest = Sha256.hash(data);
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
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

/// A file to be uploaded as part of a GraphQL multipart mutation.
class GraphQLFile {
  /// The dot-notation path in `variables` this file maps to (e.g. `variables.file`).
  final String variablePath;

  /// Absolute path to the file on disk.
  final String path;

  /// Optional filename override.
  final String? fileName;

  const GraphQLFile({
    required this.variablePath,
    required this.path,
    this.fileName,
  });
}
