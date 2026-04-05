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
