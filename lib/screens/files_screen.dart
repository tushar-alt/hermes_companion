import 'package:flutter/material.dart';

import '../api.dart';
import '../download_actions_io.dart'
    if (dart.library.html) '../download_actions_web.dart' as download_actions;
import '../models.dart';
import '../theme.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.api});

  final RelayApi api;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<FileEntry> _files = [];
  bool _loading = true;
  bool? _loadFailed;
  String? _downloading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = null;
    });
    try {
      final files = await widget.api.fetchFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _download(FileEntry f) async {
    setState(() => _downloading = f.name);
    try {
      await download_actions.downloadAndHandle(
        context,
        baseUrl: widget.api.baseUrl,
        token: widget.api.token,
        path: f.path,
        name: f.name,
        mimeType: _mimeFor(f.name),
      );
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  String _mimeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.gif')) return 'image/gif';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.apk')) return 'application/vnd.android.package-archive';
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Files — ~/Shared')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: gold, strokeWidth: 2));
    }
    if (_loadFailed == true) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: sand, size: 40),
            const SizedBox(height: 10),
            const Text('Can\'t reach your machine',
                style: TextStyle(color: sand, fontSize: 14)),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: gold)),
            ),
          ],
        ),
      );
    }
    if (_files.isEmpty) {
      return const Center(
        child: Text('Nothing in ~/Shared yet',
            style: TextStyle(color: sand, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: gold,
      backgroundColor: surface,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
        itemCount: _files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = _files[i];
          return _FileTile(
            file: f,
            downloading: _downloading == f.name,
            onDownload: () => _download(f),
          );
        },
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile(
      {required this.file, required this.downloading, required this.onDownload});

  final FileEntry file;
  final bool downloading;
  final VoidCallback onDownload;

  IconData get _icon {
    final n = file.name.toLowerCase();
    if (n.endsWith('.png') ||
        n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      return Icons.image_outlined;
    }
    if (n.endsWith('.apk')) return Icons.android_rounded;
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.zip') || n.endsWith('.tar') || n.endsWith('.gz')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch((file.mtime * 1000).round());
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: downloading ? null : onDownload,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: gold.withValues(alpha: 0.12),
                  border: Border.all(color: const Color(0x33C9A24B)),
                ),
                child: Icon(_icon, color: gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: cream,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${file.sizeLabel} · ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: sand, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (downloading)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: gold, strokeWidth: 2))
              else
                const Icon(Icons.download_rounded, color: gold, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
