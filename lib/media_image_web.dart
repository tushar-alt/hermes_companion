import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Authenticated image for the web: `Image.network` cannot send
/// Authorization headers in the browser, so the bytes are fetched ourselves
/// (with the bearer token) and rendered via `Image.memory`.
class MediaImage extends StatefulWidget {
  const MediaImage({
    super.key,
    required this.url,
    required this.headers,
    this.fit,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String url;
  final Map<String, String> headers;
  final BoxFit? fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<MediaImage> createState() => _MediaImageState();
}

class _MediaImageState extends State<MediaImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res =
          await http.get(Uri.parse(widget.url), headers: widget.headers);
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _bytes = res.bodyBytes);
      } else {
        setState(() => _failed = true);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: widget.fit, errorBuilder: widget.errorBuilder);
    }
    if (_failed) {
      final errorBuilder = widget.errorBuilder;
      if (errorBuilder != null) {
        return errorBuilder(
            context, Exception('image load failed'), StackTrace.current);
      }
      return const SizedBox.shrink();
    }
    // Mimic Image.network's loading contract (progress != null while busy) so
    // the shared loading builders render their spinner.
    final loadingBuilder = widget.loadingBuilder;
    if (loadingBuilder != null) {
      return loadingBuilder(
        context,
        const SizedBox.shrink(),
        const ImageChunkEvent(cumulativeBytesLoaded: 0, expectedTotalBytes: null),
      );
    }
    return const SizedBox.shrink();
  }
}
