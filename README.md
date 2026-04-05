# `any_link`

**Zero-Dependency Networking for Flutter. 11 Packages. 80+ Features. Nothing Missing.**

> Publisher: **ramprasadsreerama.co.in** · Same family as `any_map`

Replaces `dio`, `http`, `graphql_flutter`, `connectivity_plus`, `cached_network_image`, and every wrapper developers build on top of them.

Built directly on `dart:io` `HttpClient` (native) and `dart:html` `XHR` (web). **Zero** pub.dev dependencies.

---

## Why zero dependencies?

`dio` and `http` ARE the problem — their bugs are our bugs, their design limits our design:

- `dio#801/#925/#2377`: Upload progress lies (reports socket buffer, not server receipt)  
- `dio#718/#666`: Flutter Web uploads freeze UI (reads entire file into memory)  
- `dio#341`: App crashes when server rejects file mid-upload  
- `dio#1833`: Silent hang on network drop (no error, no callback)  
- `connectivity_plus#3440`: Returns "no internet" on Flutter Web when internet works  
- `flutter#136334/#43343`: SSE events arrive in bulk on Web instead of streaming  

---

## Package Family

| Package | Description | Depends on |
|---|---|---|
| `any_link` | Core HTTP client, interceptors, pagination, auth | dart:io only |
| `any_link_upload` | 8-phase upload pipeline with real progress | any_link, flutter |
| `any_link_download` | Resumable, parallel-chunk downloads | any_link, flutter |
| `any_link_connect` | Two-layer connectivity + offline queue | any_link, flutter |
| `any_link_test` | CLI test runner, mock server, VCR, load tester | any_link |
| `any_link_stream` | SSE (Web-fixed), WebSocket, LLM streaming | any_link, flutter |
| `any_link_cache` | Response cache, ETag, network image cache | any_link, flutter |
| `any_link_secure` | Cert pinning, HMAC signing, AES encryption | any_link |
| `any_link_devtools` | In-app inspector, health dashboard, mock toggle | any_link, flutter |
| `any_link_web3` | JSON-RPC, IPFS, decentralized gateway | any_link |
| `any_link_graphql` | GraphQL client, normalized cache, subscriptions | any_link, flutter |

**Third-party pub.dev dependencies across ALL packages: ZERO**

---

## Quick Start

```dart
import 'package:any_link/any_link.dart';

final client = AnyLinkClient(
  config: AnyLinkConfig(
    baseUrl: 'https://api.example.com',
    errorMapper: ErrorMappers.laravel,
  ),
  interceptors: [
    AuthInterceptor(
      tokenStorage: SecureTokenStorage(),
      onRefresh: (client, refresh) async {
        final res = await client.post('/auth/refresh', body: {'refresh_token': refresh});
        return TokenPair(
          accessToken: res.jsonMap['access_token'],
          refreshToken: refresh,
        );
      },
      onSessionExpired: () => navigatorKey.currentState?.pushReplacementNamed('/login'),
    ),
    LogInterceptor(prefix: 'API', level: LogLevel.basic),
    RetryInterceptor(maxRetries: 3),
    DeduplicationInterceptor(),
  ],
);

final response = await client.get('/user/me');
print(response.jsonMap);
```

---

## Upload with Real Progress

```dart
import 'package:any_link_upload/any_link_upload.dart';

final manager = UploadManager(client: client);

manager.events.listen((event) {
  switch (event.phase) {
    case Uploading() => print('${event.progressPercent}% at ${event.speed}');
    case UploadComplete(:final url) => print('Done! $url');
    case UploadFailed(:final error) => print('Error: $error');
    default => {}
  }
});

await manager.upload(UploadRequest(
  filePath: '/path/to/photo.jpg',
  endpoint: '/api/uploads',
  maxFileSizeBytes: 10 * 1024 * 1024, // 10MB
));
```

---

## Pagination — 5-line setup

```dart
final paginator = Paginator<Order>(
  client: client,
  endpoint: '/orders',
  strategy: const PageNumberStrategy(perPage: 20),
  parser: const LaravelPaginationParser(),
  fromJson: Order.fromJson,
);

// Widget:
AnyLinkPaginatedList<Order>(
  paginator: paginator,
  itemBuilder: (context, order) => OrderCard(order: order),
);
```

---

## Error Mapping

```dart
// Laravel, Django, Express, Spring Boot, Strapi, FastAPI
AnyLinkConfig(
  baseUrl: 'https://api.example.com',
  errorMapper: ErrorMappers.laravel,
)

// Usage:
on AnyLinkError catch (e) {
  if (e.isValidationError) {
    showFieldErrors(e.validationErrors!);   // {'email': ['required']}
  }
  if (e.isUnauthorized) navigateToLogin();
  print(e.fieldError('email'));             // 'required'
}
```

---

## SSE Streaming (AI / LLM)

```dart
import 'package:any_link_stream/any_link_stream.dart';

// LLM token streaming (OpenAI / Anthropic / Gemini format):
final llm = LLMStreamClient();
await for (final token in llm.streamCompletion(
  'https://api.openai.com/v1/chat/completions',
  headers: {'Authorization': 'Bearer $key'},
  body: {'model': 'gpt-4', 'stream': true, 'messages': [...]},
)) {
  stdout.write(token.text);
}
```

---

## Connectivity with Offline Queue

```dart
import 'package:any_link_connect/any_link_connect.dart';

final monitor = ConnectivityMonitor();
monitor.startMonitoring();

// Wrap your app:
ConnectivityOverlay(
  monitor: monitor,
  child: MyApp(),
)

// Queue requests offline:
final queue = OfflineQueue(client: client, monitor: monitor);
queue.enqueue(AnyLinkRequest(method: 'POST', path: '/orders', body: {...}));
```

---

## GraphQL

```dart
import 'package:any_link_graphql/any_link_graphql.dart';

final gql = GraphQLClient(httpClient: client, endpoint: '/graphql');

final result = await gql.query<User>(
  'query { user { id name email } }',
  fromJson: User.fromJson,
);

// Subscription:
gql.subscribe<Order>('subscription { orderUpdated { id status } }')
  .listen((event) => updateUI(event.data));
```

---

## CLI API Testing

```sh
API_URL=https://staging.api.com dart run any_link_test:api_check
```

```dart
final runner = ApiTestRunner(baseUrl: 'https://api.example.com');
runner.group('Auth', [
  ApiCheck('POST', '/login', body: {'email': 'test@test.com', 'password': 'secret'},
      expectedStatus: 200, saveAs: 'token', extractField: 'access_token'),
  ApiCheck('GET', '/user/me', requiresAuth: true, expectedStatus: 200),
]);
await runner.run();
// ✓ POST   /login     → 200 (142ms)
// ✓ GET    /user/me   → 200 (89ms)
// 2/2 passed · 0 failed · 231ms total
```

---

## Security

```dart
import 'package:any_link_secure/any_link_secure.dart';

// Certificate pinning:
final pinner = CertificatePinner(pins: {
  'api.example.com': ['sha256/AAAA...'],
});

// HMAC request signing (Stripe/Razorpay pattern):
client.interceptors.add(RequestSigner(secretKey: 'your_secret'));

// Payload encryption (beyond HTTPS):
client.interceptors.add(PayloadEncryptor(key: base64.decode(sharedKey)));
```

---

## In-App Network Inspector

```dart
import 'package:any_link_devtools/any_link_devtools.dart';

final inspector = NetworkInspector()..startCapturing();

// Wrap your app — tap the floating button to open:
InspectorOverlay(inspector: inspector, child: MyApp())
```

---

## Migration from dio / http

```sh
# Auto-migrate (scans your project):
dart run any_link_test:migrate
# "47 API calls found, 39 auto-migrated, 8 need manual review"
```

---

## Design Principles

1. **Zero boilerplate** — common patterns work out of the box
2. **Fully customizable** — every default overridable  
3. **Modular** — use only what you need
4. **Backend-agnostic** — Laravel, Django, Express, Spring, FastAPI, Strapi
5. **Testable** — MockServer + RequestRecorder for unit tests
6. **Observable** — every event emitted as a stream
7. **Security-first** — cert pinning, HMAC, mTLS, payload encryption, idempotency
8. **Cost-aware** — track API usage costs, respect data budgets

---

*11 packages · 80+ features · Zero third-party dependencies*  
*Publisher: ramprasadsreerama.co.in*
