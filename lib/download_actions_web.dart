import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'widgets/download_dialog.dart';

/// Download a relay file (web build): stream the bytes with the bearer
/// token, then save them through the browser's download mechanism
/// (object URL + hidden anchor click).
Future<void> downloadAndHandle(
  BuildContext context, {
  required String baseUrl,
  required String token,
  required String path,
  required String name,
  String? mimeType,
  bool fromMessage = false,
}) async {
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
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = name
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  if (context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text('Downloaded $name')));
  }
}
