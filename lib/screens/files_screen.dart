import 'package:flutter/material.dart';

import '../api.dart';
import '../download_actions_io.dart'
    if (dart.library.html) '../download_actions_web.dart' as download_actions;
import '../models.dart';
import '../storage.dart';
import '../theme.dart';

/// "Files & Health" per the design system: storage summary, a Shared Files /
/// Process Diagnostics tab pair, and (embedded in the home shell) a bottom-nav
/// destination. The Health tab mirrors the design's diagnostics card: relay
/// URL (masked, toggleable), bearer token status, latency/CORS/sync metrics
/// and a danger zone.
class FilesScreen extends StatefulWidget {
  const FilesScreen({
    super.key,
    required this.api,
    this.embedded = false,
    this.initialTab = 'files',
  });

  final RelayApi api;

  /// True when shown as a tab inside the home shell (no own app bar/back).
  final bool embedded;

  /// 'files' (Shared Files) or 'health' (Process Diagnostics).
  final String initialTab;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late String _tab;
  List<FileEntry> _files = [];
  bool _loading = true;
  bool? _loadFailed;
  String? _downloading;
  String _query = '';
  bool _showUrl = false;
  int? _latencyMs;
  bool _latencyBusy = false;
  AppPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab == 'health' ? 'health' : 'files';
    _load();
    AppPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
    if (_tab == 'health') _measureLatency();
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

  Future<void> _measureLatency() async {
    setState(() => _latencyBusy = true);
    final sw = Stopwatch()..start();
    final ok = await widget.api.ping();
    sw.stop();
    if (!mounted) return;
    setState(() {
      _latencyBusy = false;
      _latencyMs = ok ? sw.elapsedMilliseconds : null;
    });
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

  String get _storageLabel {
    var total = 0;
    for (final f in _files) {
      total += f.size;
    }
    String fmt(int bytes) {
      if (bytes >= 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
      if (bytes >= 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
      return '$bytes B';
    }

    return '${fmt(total)} used / Local Drive';
  }

  Future<void> _clearLocalCache() async {
    final prefs = _prefs ?? await AppPrefs.load();
    try {
      final chats = await widget.api.fetchChats();
      for (final c in chats) {
        await prefs.clearCache(c.id);
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local cache cleared')));
  }

  Future<void> _terminateSessions() async {
    try {
      final chats = await widget.api.fetchChats();
      for (final c in chats) {
        await widget.api.pauseChat(c.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All agent sessions paused')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reach the relay')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildContent();
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: sand, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Files & Health'),
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStorageCard(),
        _buildTabs(),
        Expanded(child: _tab == 'files' ? _buildFilesTab() : _buildHealthTab()),
      ],
    );
  }

  Widget _buildStorageCard() {
    final used = _files.fold<int>(0, (a, f) => a + f.size);
    final frac = (used / (2 * 1024 * 1024 * 1024)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ink2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('STORAGE',
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        color: sand)),
                Text(_storageLabel,
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        color: cream)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: surfaceHigh,
                color: gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(String id, String label) {
      final active = _tab == id;
      return Expanded(
        child: InkWell(
          onTap: () {
            setState(() => _tab = id);
            if (id == 'health') _measureLatency();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: active ? gold : Colors.transparent, width: 2)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? gold : sand),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          tab('files', 'Shared Files'),
          tab('health', 'Process Diagnostics'),
        ],
      ),
    );
  }

  // ── Shared Files tab ────────────────────────────────────────────────────
  Widget _buildFilesTab() {
    final filtered = _query.trim().isEmpty
        ? _files
        : _files
            .where((f) => f.name
                .toLowerCase()
                .contains(_query.trim().toLowerCase()))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: cream, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search local files…',
              hintStyle: const TextStyle(color: sand, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: sand, size: 20),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Expanded(child: _buildFileList(filtered)),
      ],
    );
  }

  Widget _buildFileList(List<FileEntry> files) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: gold, strokeWidth: 2));
    }
    if (_loadFailed == true) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: sand, size: 36),
            const SizedBox(height: 8),
            const Text('Can\'t reach your machine',
                style: TextStyle(color: sand, fontSize: 14)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry', style: TextStyle(color: gold)),
            ),
          ],
        ),
      );
    }
    if (files.isEmpty) {
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = files[i];
          return _FileRow(
            file: f,
            downloading: _downloading == f.name,
            onDownload: () => _download(f),
          );
        },
      ),
    );
  }

  // ── Process Diagnostics tab ─────────────────────────────────────────────
  Widget _buildHealthTab() {
    final api = widget.api;
    final maskedUrl = _maskUrl(api.baseUrl);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ink2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('CONNECTION STABLE',
                      style: TextStyle(
                          fontFamily: monoFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                          color: green)),
                  const Spacer(),
                  const Icon(Icons.cloud_done_rounded,
                      color: outline, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Text('RELAY URL',
                  style: TextStyle(
                      fontFamily: monoFamily, fontSize: 11, color: sand)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _showUrl ? api.baseUrl : maskedUrl,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: monoFamily,
                            fontSize: 12,
                            color: cream),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                          _showUrl
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: sand),
                      onPressed: () =>
                          setState(() => _showUrl = !_showUrl),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('BEARER TOKEN',
                  style: TextStyle(
                      fontFamily: monoFamily, fontSize: 11, color: sand)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceHigh,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      api.token.isEmpty ? 'Not set' : 'Active & Local',
                      style: TextStyle(
                          fontFamily: monoFamily,
                          fontSize: 11,
                          color: api.token.isEmpty ? red : cream),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Expires: Never (Local Context)',
                      style: TextStyle(
                          fontFamily: monoFamily,
                          fontSize: 11,
                          color: sand)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard('LATENCY', _latencyBusy
                  ? '…'
                  : _latencyMs != null
                      ? '$_latencyMs ms'
                      : '—'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard('CORS', 'Enabled',
                  valueColor: greenBright),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _metricCard('BACKGROUND SYNC', 'Active — polling every 5s',
            row: true),
        const SizedBox(height: 20),
        Text('DANGER ZONE',
            style: TextStyle(
                fontFamily: monoFamily,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                color: red)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: red.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              ListTile(
                title: const Text('Clear Local Cache',
                    style: TextStyle(
                        color: onRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: const Text('Frees local storage.',
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        color: sand)),
                trailing: OutlinedButton(
                  onPressed: _clearLocalCache,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onRed,
                    side: BorderSide(color: red.withValues(alpha: 0.5)),
                  ),
                  child: const Text('Clear',
                      style: TextStyle(
                          fontFamily: monoFamily, fontSize: 11)),
                ),
              ),
              const Divider(height: 1, color: Color(0x33F85149)),
              ListTile(
                title: const Text('Terminate All Sessions',
                    style: TextStyle(
                        color: onRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: const Text('Pauses every agent session.',
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        color: sand)),
                trailing: FilledButton(
                  onPressed: _terminateSessions,
                  style: FilledButton.styleFrom(
                    backgroundColor: redDeep,
                    foregroundColor: onRed,
                  ),
                  child: const Text('Terminate',
                      style: TextStyle(
                          fontFamily: monoFamily, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value,
      {Color? valueColor, bool row = false}) {
    final content = row
        ? Row(
            children: [
              const Icon(Icons.sync_rounded, color: gold, size: 18),
              const SizedBox(width: 8),
              Text(value,
                  style: TextStyle(
                      fontFamily: monoFamily,
                      fontSize: 12,
                      color: cream)),
            ],
          )
        : Text(value,
            style: TextStyle(
                fontFamily: monoFamily,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: valueColor ?? cream));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(fontFamily: monoFamily, fontSize: 11, color: sand)),
          const SizedBox(height: 6),
          content,
        ],
      ),
    );
  }

  String _maskUrl(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return url;
    final host = u.host;
    if (host.length <= 12) return '${u.scheme}://$host/…';
    return '${u.scheme}://${host.substring(0, 12)}…/relay/…';
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.downloading,
    required this.onDownload,
  });

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
    if (n.endsWith('.js') || n.endsWith('.dart') || n.endsWith('.py')) {
      return Icons.javascript;
    }
    if (n.endsWith('.json') || n.endsWith('.yaml') || n.endsWith('.yml')) {
      return Icons.data_object;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.fromMillisecondsSinceEpoch((file.mtime * 1000).round());
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final dateLabel = sameDay
        ? 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    return Material(
      color: ink2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onDownload,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(_icon, color: outline, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: cream, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('${file.sizeLabel} • $dateLabel',
                        style: TextStyle(
                            fontFamily: monoFamily,
                            fontSize: 11,
                            color: sand)),
                  ],
                ),
              ),
              if (downloading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: gold, strokeWidth: 2))
              else
                IconButton(
                  icon: const Icon(Icons.download_rounded,
                      color: sand, size: 20),
                  onPressed: onDownload,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
