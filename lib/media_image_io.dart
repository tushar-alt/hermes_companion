import 'package:flutter/material.dart';

/// Authenticated network image for device builds — `Image.network` with
/// request headers (the relay's `/api/media` requires a bearer token).
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
  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      headers: widget.headers,
      fit: widget.fit,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: widget.errorBuilder,
    );
  }
}
