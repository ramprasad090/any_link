import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_io.dart';

/// A streaming multipart/form-data body builder.
///
/// Works on all platforms. On native, files are streamed from disk.
/// On web, use [addFileBytes] with in-memory bytes instead of [addFile].
///
/// ```dart
/// final form = AnyLinkFormData();
/// form.addField('name', 'Alice');
/// form.addFileBytes('avatar', bytes, fileName: 'photo.jpg');
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

  /// Add a file from in-memory bytes. Works on all platforms including web.
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

  /// Add a file from a path on disk. Native platforms only.
  ///
  /// On Flutter Web, use [addFileBytes] instead.
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

  /// The `Content-Type` header value for this form.
  String get contentTypeHeader => 'multipart/form-data; boundary=$boundary';

  /// Approximate total byte count.
  Future<int> get totalBytes async {
    int total = 0;
    for (final part in _parts) {
      total += await part.sizeBytes(boundary);
    }
    total += '--$boundary--\r\n'.length;
    return total;
  }

  /// Stream the form data without buffering all parts at once.
  Stream<List<int>> toStream() async* {
    for (final part in _parts) {
      yield* part.toStream(boundary);
    }
    yield utf8.encode('--$boundary--\r\n');
  }

  static String _generateBoundary() {
    final rng = Random.secure();
    return List.generate(
        16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static String _mimeFromExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'png': 'image/png', 'gif': 'image/gif',
      'webp': 'image/webp', 'mp4': 'video/mp4',
      'mov': 'video/quicktime', 'pdf': 'application/pdf',
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
      '--$boundary\r\nContent-Disposition: form-data; name="$fieldName"; '
      'filename="$fileName"\r\nContent-Type: $contentType\r\n\r\n';

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

// _FilePart delegates file I/O to platform-conditional helpers.
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
      '--$boundary\r\nContent-Disposition: form-data; name="$fieldName"; '
      'filename="$fileName"\r\nContent-Type: $contentType\r\n\r\n';

  @override
  Future<int> sizeBytes(String boundary) {
    final h = _header(boundary);
    return readFileSize(filePath, utf8.encode(h).length);
  }

  @override
  Stream<List<int>> toStream(String boundary) {
    final h = _header(boundary);
    return readFileStream(filePath, utf8.encode(h).length, h);
  }
}
