## 1.1.0

- Implemented real SHA-256 (FIPS 180-4) and HMAC-SHA256 in pure Dart — zero third-party dependencies
- Implemented AES-256-CTR payload encryption replacing XOR placeholder
- Wired HTTP/2 via ALPN negotiation (SecurityContext) when enableHttp2 is true
- GraphQL: Auto-Persisted Queries (APQ) with SHA-256 hashing
- GraphQL: File upload via multipart request spec
- Upload: real SHA-256 file hashing for server-side deduplication
- Upload: fixed retry() which previously threw UnimplementedError


