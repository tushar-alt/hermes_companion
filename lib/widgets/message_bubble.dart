import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../markdown.dart';
import '../models.dart';
import '../theme.dart';
import 'cartoon_avatar.dart';
import 'download_dialog.dart';

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

  /// Seed for the assistant's cartoon avatar (chat id).
  final String seed;

  /// True when this is a user message whose send failed (kept visible).
  final bool failed;

  /// Called when the user taps the "not sent" chip to retry.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final radius = Radius.circular(isUser ? 18 : 16);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2, right: 8),
              child: CartoonAvatar(seed: seed, size: 28),
            ),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
              decoration: BoxDecoration(
                gradient: isUser ? goldGradient : null,
                color: isUser ? null : surface,
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: isUser ? radius : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : radius,
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0x2EC9A24B)),
                boxShadow: isUser
                    ? const [BoxShadow(color: Color(0x33C9A24B), blurRadius: 12)]
                    : const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 8,
                            offset: Offset(0, 3)),
                      ],
              ),
              // IntrinsicWidth: the bubble must be only as wide as its
              // content. Without it the timestamp's Align expands to fill all
              // available width and stretches the bubble full-screen.
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              color: bg,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : MarkdownText(
                            message.text,
                            style: const TextStyle(
                              color: cream,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _time(message.ts),
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? bg.withValues(alpha: 0.6)
                            : const Color(0x99C9A24B),
                      ),
                    ),
                  ),
                  if (failed)
                    GestureDetector(
                      onTap: onRetry,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg.withValues(alpha: 0.18),
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
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 240, maxHeight: 240),
              child: Image.network(
                url,
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
                    borderRadius: BorderRadius.circular(12),
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
          color: (isUser ? bg : ink2).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: gold.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_fileIcon(name), size: 16, color: isUser ? bg : gold),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    color: isUser ? bg : cream,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (!isUser) ...[
              const SizedBox(width: 5),
              const Icon(Icons.download, size: 13, color: sand),
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

  /// Download a shared file (with progress), then offer Install/Open + Share.
  Future<void> _openFileActions(
      BuildContext context, String path, String name) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final file = await showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DownloadProgressDialog(
        fileName: name,
        baseUrl: baseUrl,
        token: token,
        path: path,
      ),
    );
    if (file == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Download failed — relay unreachable?')));
      return;
    }
    if (!context.mounted) return;
    final isApk = name.toLowerCase().endsWith('.apk');
    await showModalBottomSheet(
      context: context,
      backgroundColor: ink2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sand.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                    color: cream, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(isApk ? Icons.android : Icons.open_in_new,
                  color: gold),
              title: Text(isApk ? 'Install' : 'Open',
                  style: const TextStyle(color: cream, fontSize: 14)),
              onTap: () async {
                navigator.pop();
                final res = await OpenFilex.open(file.path);
                if (res.type != ResultType.done &&
                    res.type != ResultType.noAppToOpen) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Could not open: ${res.message}')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: gold),
              title: const Text('Share',
                  style: TextStyle(color: cream, fontSize: 14)),
              onTap: () async {
                navigator.pop();
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(file.path)],
                  text: name,
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
              child: Image.network(
                url,
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
