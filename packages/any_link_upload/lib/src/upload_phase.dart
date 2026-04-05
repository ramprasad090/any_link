/// Sealed hierarchy of upload pipeline phases.
///
/// Use pattern matching in your UI to show the right state:
/// ```dart
/// switch (event.phase) {
///   case Validating() => Text('Validating…'),
///   case Compressing(:final originalSize) => Text('Compressing ${_fmt(originalSize)}…'),
///   case Hashing() => Text('Dedup check…'),
///   case Uploading() => LinearProgressIndicator(value: event.progressPercent / 100),
///   case ServerProcessing() => Text('Processing on server…'),
///   case Retrying(:final attempt, :final maxAttempts) => Text('Retry $attempt/$maxAttempts…'),
///   case UploadComplete(:final url) => Text('Done! $url'),
///   case UploadFailed(:final error) => Text('Failed: $error', style: errorStyle),
///   case UploadCancelled() => Text('Cancelled'),
/// }
/// ```
sealed class UploadPhase {
  const UploadPhase();
}

final class Validating extends UploadPhase {
  const Validating();
}

final class Compressing extends UploadPhase {
  final int originalSize;
  final int? compressedSize;
  const Compressing({required this.originalSize, this.compressedSize});
}

final class Hashing extends UploadPhase {
  const Hashing();
}

final class Uploading extends UploadPhase {
  const Uploading();
}

final class ServerProcessing extends UploadPhase {
  const ServerProcessing();
}

final class Retrying extends UploadPhase {
  final int attempt;
  final int maxAttempts;
  final Duration nextIn;
  const Retrying({required this.attempt, required this.maxAttempts, required this.nextIn});
}

final class UploadComplete extends UploadPhase {
  final String? url;
  final Map<String, dynamic>? serverResponse;
  const UploadComplete({this.url, this.serverResponse});
}

final class UploadFailed extends UploadPhase {
  final String error;
  const UploadFailed({required this.error});
}

final class UploadCancelled extends UploadPhase {
  const UploadCancelled();
}
