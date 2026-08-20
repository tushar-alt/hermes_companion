import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../theme.dart';

/// Stream-download a relay file, reporting byte progress. Returns the raw
/// bytes (platform-neutral: the caller decides what to do with them — save
/// to a file on device, or trigger a browser download on the web).
Future<Uint8List> streamDownload({
  required String baseUrl,
  required String token,
  required String path,
  required String name,
  required void Function(int received, int total) onProgress,
}) async {
  final api = RelayApi(baseUrl, token: token);
  final res = await api.streamMedia(path);
  final total = res.contentLength ?? 0;
  final builder = BytesBuilder(copy: false);
  var received = 0;
  await for (final chunk in res.stream) {
    builder.add(chunk);
    received += chunk.length;
    onProgress(received, total);
  }
  return builder.takeBytes();
}

/// Modal download dialog with a real progress bar; pops with the downloaded
/// bytes on success, or null on failure.
class DownloadProgressDialog extends StatefulWidget {
  const DownloadProgressDialog({
    super.key,
    required this.fileName,
    required this.baseUrl,
    required this.token,
    required this.path,
  });

  final String fileName;
  final String baseUrl;
  final String token;
  final String path;

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  int _received = 0;
  int _total = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final bytes = await streamDownload(
        baseUrl: widget.baseUrl,
        token: widget.token,
        path: widget.path,
        name: widget.fileName,
        onProgress: (r, t) {
          if (mounted) {
            setState(() {
              _received = r;
              _total = t;
            });
          }
        },
      );
      if (mounted) Navigator.of(context).pop(bytes);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _fmt(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final frac = _total > 0 ? (_received / _total).clamp(0.0, 1.0) : null;
    final pct = frac == null ? '' : '${(frac * 100).round()}%';
    return Dialog(
      backgroundColor: ink2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.fileName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                    color: cream, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (_failed) ...[
              const Row(children: [
                Icon(Icons.error_outline, color: red, size: 20),
                SizedBox(width: 8),
                Text('Download failed — check connection',
                    style: TextStyle(color: cream, fontSize: 12)),
              ]),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 6,
                  backgroundColor: bg,
                  color: gold,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_fmt(_received)} / ${_fmt(_total)}',
                      style: const TextStyle(color: sand, fontSize: 11)),
                  Text(pct,
                      style: const TextStyle(
                          color: gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
