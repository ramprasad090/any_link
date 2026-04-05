/// Sealed hierarchy of download pipeline phases.
sealed class DownloadPhase {
  const DownloadPhase();
}

final class DownloadPending extends DownloadPhase {
  const DownloadPending();
}

final class DownloadConnecting extends DownloadPhase {
  const DownloadConnecting();
}

final class Downloading extends DownloadPhase {
  const Downloading();
}

final class MergingChunks extends DownloadPhase {
  const MergingChunks();
}

final class VerifyingIntegrity extends DownloadPhase {
  const VerifyingIntegrity();
}

final class DownloadComplete extends DownloadPhase {
  final String savedPath;
  const DownloadComplete({required this.savedPath});
}

final class DownloadFailed extends DownloadPhase {
  final String error;
  const DownloadFailed({required this.error});
}

final class DownloadCancelled extends DownloadPhase {
  const DownloadCancelled();
}

final class DownloadPaused extends DownloadPhase {
  final int bytesReceived;
  const DownloadPaused({required this.bytesReceived});
}
