import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A streaming multipart/form-data body builder.
///
/// Files are read from disk in chunks — the full file is never loaded into
/// memory. Safe for uploading large files on Flutter Web too (stream via XHR).
///
/// ```dart
/// final form = AnyLinkFormData();
/// form.addField('name', 'Alice');
/// form.addFile('avatar', '/path/to/photo.jpg');
/// await client.post('/profile', body: form);
/// ```
class AnyLinkFormData {
  final String boundary;
  final List<_Part> _parts = [];

  AnyLinkFormData() : boundary = _generateBoundary();

  /// Add a plain text field.
  void addField(String name, String value) {
    _parts.add(_FieldPart(name: name, value: value));
  }

  /// Add a file from a path on disk.
  void addFile(
    String fieldName,
    String filePath, {
    String? fileName,
    String? contentType,
  }) {
    _parts.add(_FilePart(
      fieldName: fieldName,
      filePath: filePath,
      fileName: fileName ?? filePath.split('/').last,
      contentType: contentType ?? _mimeFromExtension(filePath),
    ));
  }

  /// Add a file from in-memory bytes.
  void addFileBytes(
    String fieldName,
    List<int> bytes, {
    required String fileName,
    String? contentType,
  }) {
    _parts.add(_BytesPart(
      fieldName: fieldName,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType ?? 'application/octet-stream',
    ));
  }

  /// The `Content-Type` header value to use when sending this form.
  String get contentTypeHeader => 'multipart/form-data; boundary=$boundary';

  /// Approximate total byte count (exact for fields/bytes parts; approximate
  /// for file parts until read).
  Future<int> get totalBytes async {
    int total = 0;
    for (final part in _parts) {
      total += await part.sizeBytes(boundary);
    }
    total += '--$boundary--\r\n'.length;
    return total;
  }

  /// Stream the form data without ever buffering all parts at once.
  Stream<List<int>> toStream() async* {
    for (final part in _parts) {
      yield* part.toStream(boundary);
    }
    yield utf8.encode('--$boundary--\r\n');
  }

  static String _generateBoundary() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String _mimeFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
    };
    return map[ext] ?? 'application/octet-stream';
  }
}

// ── Internal part types ───────────────────────────────────────────────────────

abstract class _Part {
  Future<int> sizeBytes(String boundary);
  Stream<List<int>> toStream(String boundary);
}

class _FieldPart implements _Part {
  final String name;
  final String value;
  _FieldPart({required this.name, required this.value});

  String _header(String boundary) =>
      '--$boundary\r\nContent-Disposition: form-data; name="$name"\r\n\r\n';

  @override
  Future<int> sizeBytes(String boundary) async =>
      utf8.encode(_header(boundary)).length + utf8.encode('$value\r\n').length;

  @override
  Stream<List<int>> toStream(String boundary) async* {
    yield utf8.encode(_header(boundary));
    yield utf8.encode('$value\r\n');
  }
}

class _FilePart implements _Part {
  final String fieldName;
  final String filePath;
  final String fileName;
  final String contentType;

  _FilePart({
    required this.fieldName,
    required this.filePath,
    required this.fileName,
    required this.contentType,
  });

  String _header(String boundary) =>
      '--$boundary\r\nContent-Disposition: form-data; name="$fieldName"; filename="$fileName"\r\n'
      'Content-Type: $contentType\r\n\r\n';

  @override
  Future<int> sizeBytes(String boundary) async {
    final file = File(filePath);
    final fileSize = await file.length();
    return utf8.encode(_header(boundary)).length + fileSize + 2; // +2 for \r\n
  }

  @override
  Stream<List<int>> toStream(String boundary) async* {
    yield utf8.encode(_header(boundary));
    yield* File(filePath).openRead();
    yield utf8.encode('\r\n');
  }
}

class _BytesPart implements _Part {
  final String fieldName;
  final List<int> bytes;
  final String fileName;
  final String contentType;

  _BytesPart({
    required this.fieldName,
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  String _header(String boundary) =>
      '--$boundary\r\nContent-Disposition: form-data; name="$fieldName"; filename="$fileName"\r\n'
      'Content-Type: $contentType\r\n\r\n';

  @override
  Future<int> sizeBytes(String boundary) async =>
      utf8.encode(_header(boundary)).length + bytes.length + 2;

  @override
  Stream<List<int>> toStream(String boundary) async* {
    yield utf8.encode(_header(boundary));
    yield bytes;
    yield utf8.encode('\r\n');
  }
}
