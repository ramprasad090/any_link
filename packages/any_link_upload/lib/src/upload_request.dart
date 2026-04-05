/// Configuration for a single upload operation.
class UploadRequest {
  /// Path on disk of the file to upload.
  final String filePath;

  /// API endpoint that accepts the upload.
  final String endpoint;

  /// Field name for the file in the multipart form. Default: `"file"`.
  final String fieldName;

  /// Additional form fields sent alongside the file.
  final Map<String, String>? additionalFields;

  /// Additional HTTP headers.
  final Map<String, String>? headers;

  /// Maximum file size in bytes. The upload is rejected before any data is
  /// sent. Default: 100 MB.
  final int maxFileSizeBytes;

  /// Allowed MIME types. Empty list = accept all.
  final List<String> allowedMimeTypes;

  /// Called with a [File] path before upload. Return the path of the
  /// compressed file (may be the same path if no compression needed).
  final Future<String> Function(String originalPath)? compress;

  /// Endpoint to check for server-side dedup.
  /// Receives `{"hash": "<sha256>"}`. Returns `{"exists": true, "url": "..."}` to skip upload.
  final String? dedupEndpoint;

  /// Number of bytes per chunk for chunked upload. null = single part.
  final int? chunkSize;

  /// Maximum retry attempts on failure. Default: 3.
  final int maxRetries;

  /// Unique identifier; auto-generated if not supplied.
  final String? id;

  const UploadRequest({
    required this.filePath,
    required this.endpoint,
    this.fieldName = 'file',
    this.additionalFields,
    this.headers,
    this.maxFileSizeBytes = 100 * 1024 * 1024,
    this.allowedMimeTypes = const [],
    this.compress,
    this.dedupEndpoint,
    this.chunkSize,
    this.maxRetries = 3,
    this.id,
  });
}
