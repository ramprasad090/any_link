Future<int> readFileSize(String path, int headerLen) async =>
    throw UnsupportedError('File access is not supported on this platform. Use addFileBytes() instead.');

Stream<List<int>> readFileStream(String path, int headerLen, String header) =>
    throw UnsupportedError('File access is not supported on this platform. Use addFileBytes() instead.');
