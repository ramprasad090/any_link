/// Configuration for a single download operation.
class DownloadRequest {
  /// Full URL of the remote file.
  final String url;

  /// Absolute path where the file should be saved.
  final String savePath;

  /// Additional request headers.
  final Map<String, String>? headers;

  /// Resume using HTTP `Range` header if a partial file exists.
  final bool resumable;

  /// Download the file in [chunkCount] parallel requests and merge.
  final bool parallelChunks;

  /// Number of parallel chunks (used when [parallelChunks] is true).
  final int chunkCount;

  /// Expected SHA-256 hex hash for integrity verification. Skip if null.
  final String? expectedHash;

  /// Maximum retry attempts. Default: 3.
  final int maxRetries;

  /// Unique ID; auto-generated if not supplied.
  final String? id;

  const DownloadRequest({
    required this.url,
    required this.savePath,
    this.headers,
    this.resumable = true,
    this.parallelChunks = false,
    this.chunkCount = 4,
    this.expectedHash,
    this.maxRetries = 3,
    this.id,
  });
}
