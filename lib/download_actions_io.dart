import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'theme.dart';
import 'widgets/download_dialog.dart';

/// Download a relay file and then act on it (device builds).
///
/// Shows the progress dialog, saves the bytes to a temp file, then:
/// - [fromMessage] true  → bottom sheet with Open/Install + Share
///   (message media chips)
/// - [fromMessage] false → system share sheet (files screen)
Future<void> downloadAndHandle(
  BuildContext context, {
  required String baseUrl,
  required String token,
  required String path,
  required String name,
  String? mimeType,
  bool fromMessage = false,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final bytes = await showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DownloadProgressDialog(
      fileName: name,
      baseUrl: baseUrl,
      token: token,
      path: path,
    ),
  );
  if (bytes == null) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Download failed — relay unreachable?')));
    return;
  }
  if (!context.mounted) return;

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  if (!context.mounted) return;

  if (fromMessage) {
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
                style: GoogleFonts.inter(
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
                  files: [XFile(file.path, mimeType: mimeType)],
                  text: name,
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  } else {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      title: name,
      subject: name,
    ));
  }
}
