import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// In-memory LRU image cache.
class _ImageCache {
  static final _ImageCache _instance = _ImageCache._();
  factory _ImageCache() => _instance;
  _ImageCache._();

  final Map<String, Uint8List> _store = {};
  final List<String> _lruKeys = [];
  static const int _maxEntries = 100;

  Uint8List? get(String url) => _store[url];

  void put(String url, Uint8List bytes) {
    _store[url] = bytes;
    _lruKeys.remove(url);
    _lruKeys.add(url);
    if (_lruKeys.length > _maxEntries) {
      final evict = _lruKeys.removeAt(0);
      _store.remove(evict);
    }
  }
}

/// Network image widget with memory LRU + optional disk cache.
///
/// Replaces `cached_network_image` with zero extra dependencies.
///
/// ```dart
/// AnyLinkImage(
///   url: 'https://example.com/photo.jpg',
///   width: 200,
///   height: 200,
///   fit: BoxFit.cover,
///   placeholder: const CircularProgressIndicator(),
/// )
/// ```
class AnyLinkImage extends StatefulWidget {
  final String url;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Map<String, String>? headers;
  final String? diskCachePath;

  const AnyLinkImage({
    super.key,
    required this.url,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit,
    this.headers,
    this.diskCachePath,
  });

  @override
  State<AnyLinkImage> createState() => _AnyLinkImageState();
}

class _AnyLinkImageState extends State<AnyLinkImage> {
  final _cache = _ImageCache();
  Uint8List? _bytes;
  bool _error = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Check memory cache.
    final cached = _cache.get(widget.url);
    if (cached != null) {
      setState(() {
        _bytes = cached;
        _loading = false;
      });
      return;
    }

    // Check disk cache.
    if (widget.diskCachePath != null) {
      final cacheFile = File('${widget.diskCachePath}/${_urlToFileName(widget.url)}');
      if (await cacheFile.exists()) {
        final diskBytes = await cacheFile.readAsBytes();
        _cache.put(widget.url, diskBytes);
        if (mounted) {
          setState(() {
            _bytes = diskBytes;
            _loading = false;
          });
        }
        return;
      }
    }

    // Fetch from network.
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final req = await client.openUrl('GET', Uri.parse(widget.url));
      widget.headers?.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close();
      final chunks = <List<int>>[];
      await for (final chunk in res) {
        chunks.add(chunk);
      }
      client.close();

      final bytes = Uint8List.fromList(chunks.expand((c) => c).toList());
      _cache.put(widget.url, bytes);

      // Write to disk cache.
      if (widget.diskCachePath != null) {
        final cacheFile = File('${widget.diskCachePath}/${_urlToFileName(widget.url)}');
        await cacheFile.parent.create(recursive: true);
        await cacheFile.writeAsBytes(bytes);
      }

      if (mounted) setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  String _urlToFileName(String url) {
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').substring(0, 50.clamp(0, url.length));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.placeholder ?? const SizedBox.shrink();
    if (_error) return widget.errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey);

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) =>
          widget.errorWidget ?? const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
