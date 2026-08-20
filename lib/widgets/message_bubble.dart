import 'package:flutter/material.dart';

import '../download_actions_io.dart'
    if (dart.library.html) '../download_actions_web.dart' as download_actions;
import '../markdown.dart';
import '../media_image_io.dart'
    if (dart.library.html) '../media_image_web.dart' as media;
import '../models.dart';
import '../theme.dart';
import 'icon_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.baseUrl,
    required this.token,
    this.seed = 'main',
    this.failed = false,
    this.onRetry,
  });

  final ChatMessage message;
  final String baseUrl;
  final String token;

  /// Seed for the assistant's avatar (chat id).
  final String seed;

  /// True when this is a user message whose send failed (kept visible).
  final bool failed;

  /// Called when the user taps the "not sent" chip to retry.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            IconAvatar(seed: seed, size: 28, icon: Icons.smart_toy_rounded),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              decoration: BoxDecoration(
                color: isUser ? ink2 : surface,
                borderRadius: BorderRadius.only(
                  topLeft: isUser ? const Radius.circular(8) : Radius.zero,
                  topRight: isUser ? Radius.zero : const Radius.circular(8),
                  bottomLeft: const Radius.circular(8),
                  bottomRight: const Radius.circular(8),
                ),
                border: Border.all(color: borderColor),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 10, 13, 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.media.isNotEmpty) ...[
                            for (final path in message.media)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: MediaView(
                                    path: path,
                                    baseUrl: baseUrl,
                                    token: token,
                                    isUser: isUser),
                              ),
                          ],
                          if (message.text.isNotEmpty)
                            isUser
                                ? Text(
                                    message.text,
                                    style: const TextStyle(
                                      color: cream,
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  )
                                : MarkdownText(
                                    message.text,
                                    style: const TextStyle(
                                      color: cream,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(13, 0, 10, 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _time(message.ts),
                            style: TextStyle(
                              fontFamily: monoFamily,
                              fontSize: 10,
                              color: outline,
                            ),
                          ),
                          if (isUser) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.done_all_rounded,
                                size: 13, color: sand),
                          ],
                        ],
                      ),
                    ),
                    if (failed)
                      GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(13, 0, 13, 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: redDeep.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 12, color: red),
                              SizedBox(width: 4),
                              Text('Not sent — tap to retry',
                                  style: TextStyle(
                                      color: red,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _time(double ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class MediaView extends StatelessWidget {
  const MediaView({
    super.key,
    required this.path,
    required this.baseUrl,
    required this.token,
    required this.isUser,
  });

  final String path;
  final String baseUrl;
  final String token;
  final bool isUser;

  bool get _isImage => RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false)
      .hasMatch(path);

  @override
  Widget build(BuildContext context) {
    final url = '$baseUrl/api/media?path=${Uri.encodeQueryComponent(path)}';
    final headers = {'Authorization': 'Bearer $token'};
    if (_isImage) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            url: url,
            headers: headers,
            heroTag: 'media-$path',
          ),
        )),
        child: Hero(
          tag: 'media-$path',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 240, maxHeight: 240),
              child: media.MediaImage(
                url: url,
                headers: headers,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 200,
                    height: 140,
                    color: bg.withValues(alpha: 0.4),
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: gold, strokeWidth: 2)),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  width: 200,
                  height: 100,
                  decoration: BoxDecoration(
                    color: bg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_outlined,
                          color: sand, size: 22),
                      const SizedBox(height: 4),
                      Text(path.split('/').last,
                          style:
                              const TextStyle(color: sand, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // Non-image file chip → tap to download, install or share.
    final name = path.split('/').last;
    return GestureDetector(
      onTap: () => _openFileActions(context, path, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: (isUser ? bg : ink2).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon(name), size: 16, color: gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    color: cream,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(width: 5),
              const Icon(Icons.download_rounded, size: 13, color: sand),
            ],
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.apk')) return Icons.android;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.zip') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz')) {
      return Icons.folder_zip;
    }
    if (RegExp(r'\.(mp3|wav|m4a|ogg)$').hasMatch(lower)) {
      return Icons.audiotrack;
    }
    if (RegExp(r'\.(mp4|mov|mkv|webm)$').hasMatch(lower)) {
      return Icons.movie;
    }
    return Icons.insert_drive_file;
  }

  /// Download a shared file (with progress), then offer Install/Open + Share
  /// on device, or save it through the browser on the web.
  Future<void> _openFileActions(
      BuildContext context, String path, String name) async {
    await download_actions.downloadAndHandle(
      context,
      baseUrl: baseUrl,
      token: token,
      path: path,
      name: name,
      fromMessage: true,
    );
  }
}

/// Full-screen pinch-zoom image viewer.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen(
      {super.key, required this.url, required this.headers, required this.heroTag});

  final String url;
  final Map<String, String> headers;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: media.MediaImage(
                url: url,
                headers: headers,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: CircularProgressIndicator(
                            color: gold, strokeWidth: 2),
                      ),
                errorBuilder: (_, _, _) => const Center(
                  child: Text('image unavailable',
                      style: TextStyle(color: sand)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
