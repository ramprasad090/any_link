## 1.2.2

- Change enableHttp2 default to false — HTTP/2 ALPN breaks shared hosting (Hostinger, cPanel, etc.) that only supports HTTP/1.1. Opt in explicitly with enableHttp2: true.

## 1.2.1

- Fix "AnyLinkTransport not found" on Flutter Web by separating the abstract class into any_link_transport.dart imported unconditionally

## 1.2.0

- Full Flutter Web support via platform-adaptive transport
- Native platforms (Android, iOS, macOS, Windows, Linux): dart:io HttpClient
- Web platform: dart:html XHR with arraybuffer response
- AnyLinkFormData: addFile() is now native-only; addFileBytes() works on all platforms
- Conditional imports: transport_io.dart / transport_web.dart / transport_stub.dart

## 1.1.0

- Implemented real SHA-256 (FIPS 180-4) and HMAC-SHA256 in pure Dart — zero third-party dependencies
- Implemented AES-256-CTR payload encryption replacing XOR placeholder
- Wired HTTP/2 via ALPN negotiation (SecurityContext) when enableHttp2 is true
- GraphQL: Auto-Persisted Queries (APQ) with SHA-256 hashing
- GraphQL: File upload via multipart request spec
- Upload: real SHA-256 file hashing for server-side deduplication
- Upload: fixed retry() which previously threw UnimplementedError

## 1.0.0

* Initial release.
* HTTP client built on `dart:io` — zero pub.dev dependencies.
* Auth interceptor with Completer-queue token refresh (single refresh per 401 burst).
* pm2-style prefixed logger with ConsoleSink, FileSink, StreamSink.
* 6 backend error mappers: Laravel, Django, Express, Spring Boot, Strapi, FastAPI.
* Retry interceptor with exponential back-off + Retry-After support.
* Request deduplication interceptor.
* Transform interceptor (snake_case ↔ camelCase, type coercion).
* Versioning interceptor with Sunset/Deprecation header detection.
* Idempotency key interceptor.
* Rate limiter (client-side, queue-based).
* Analytics interceptor with p50/p95/p99 statistics.
* Batch manager (single HTTP call for N requests).
* Full pagination system: 4 strategies, 6 backend parsers, 3 widgets.
* API module base class for feature-based organisation.
* DNS pre-resolver for cold-start latency.
* API contract validator (runtime schema checks).
* Cost tracker for AI/LLM API usage budgets.
* Multipart form data streamed from disk (no full-file memory load).
* CancelToken built on Completer (no external dependency).
