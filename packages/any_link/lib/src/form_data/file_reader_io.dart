import 'dart:convert';
import 'dart:io';

Future<int> readFileSize(String path, int headerLen) async {
  final fileSize = await File(path).length();
  return headerLen + fileSize + 2; // +2 for \r\n
}

Stream<List<int>> readFileStream(
    String path, int headerLen, String header) async* {
  yield utf8.encode(header);
  yield* File(path).openRead();
  yield utf8.encode('\r\n');
}
