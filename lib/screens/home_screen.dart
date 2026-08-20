import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../agent_prompt.dart';
import '../api.dart';
import '../models.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets/chat_tile.dart';
import '../widgets/help_drawer.dart';
import 'chat_screen.dart';
import 'files_screen.dart';

/// Sorts the session list: Hermes Admin (main chat) pinned on top, then
/// chats by latest activity (most recent response first), then by name.
List<ChatInfo> sortChats(
    List<ChatInfo> chats, double Function(ChatInfo) activity) {
  final sorted = List<ChatInfo>.of(chats);
  sorted.sort((a, b) {
    if (a.isMain != b.isMain) return a.isMain ? -1 : 1;
    final ta = activity(a);
    final tb = activity(b);
    if (ta != tb) return tb.compareTo(ta);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

/// Home shell per the design system: a responsive header (desktop top bar or
/// mobile header), the chat list and Files/Health tabs, and a mobile bottom
/// navigation (Chats / Files / Health).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppPrefs? _prefs;
  RelayApi _api = RelayApi(defaultServerUrl);
  String _serverUrl = defaultServerUrl;
  String _token = '';
  bool _connected = false;
  bool? _everChecked;
  List<ChatInfo> _chats = [];
  Map<String, ChatStatus> _statuses = {};
  Timer? _timer;
  bool _booted = false;
  bool _appVisible = true;
  int _tab = 0; // 0 chats, 1 files, 2 health

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Guarded by [_booted]: this can fire before _boot() finishes, and
    // touching uninitialized state there used to crash cold starts.
    if (!_booted) return;
    _appVisible = state == AppLifecycleState.resumed;
    _prefs?.setAppForeground(_appVisible);
    if (_appVisible) _reload();
  }

  Future<void> _boot() async {
    _prefs = await AppPrefs.load();
    _serverUrl = _prefs!.serverUrl;
    _token = _prefs!.token;
    _api = RelayApi(_serverUrl, token: _token);
    await _prefs!.setAppForeground(true);
    await _reload();
    _booted = true;
    // Only poll while the app is actually on screen — the foreground
    // service already covers background notifications, so this timer
    // must not burn battery behind the user's back.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_appVisible && _booted) _reload();
    });
  }

  Future<void> _reload() async {
    try {
      final chats = await _api.fetchChats();
      final statuses = await _api.fetchStatus();
      if (!mounted) return;
      setState(() {
        _chats = sortChats(chats, _activitySeconds);
        _statuses = statuses;
        _connected = true;
        _everChecked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _everChecked = true;
      });
    }
  }

  /// Latest activity for a chat: the relay's `lastTs` if provided, otherwise
  /// the locally tracked timestamp of the last message seen in it.
  double _activitySeconds(ChatInfo chat) {
    final localMs = _prefs?.lastActiveFor(chat.id) ?? 0;
    final local = localMs / 1000;
    final relay = chat.lastTs;
    return relay > local ? relay : local;
  }

  void _openChat(ChatInfo chat) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) =>
            ChatScreen(chatId: chat.id, chatName: chat.name),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> _createChat() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New chat', style: TextStyle(fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: cream),
          decoration: const InputDecoration(
            hintText: 'Chat name (e.g. Trip Planning)',
            hintStyle: TextStyle(color: sand),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: borderColor)),
            focusedBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: gold)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: sand))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: gold),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create', style: TextStyle(color: onPrimary)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final chat = await _api.createChat(name);
      if (!mounted) return;
      _openChat(chat);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not create chat — relay unreachable?')));
    }
  }

  /// Asks for confirmation; returns true when the user wants to delete.
  Future<bool> _confirmDelete(ChatInfo chat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?', style: TextStyle(fontSize: 17)),
        content: Text(
            '“${chat.name}” will be terminated everywhere: the agent session '
            'stops, and the conversation and its files are removed.',
            style: const TextStyle(color: cream, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: sand))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: redDeep),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: onRed)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Deletes the chat EVERYWHERE: the relay removes it and terminates the
  /// agent session, and all local phone state for it is wiped too.
  Future<void> _deleteChat(ChatInfo chat) async {
    try {
      final ok = await _api.deleteChat(chat.id);
      if (ok) {
        await _prefs!.clearChat(chat.id);
      }
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete failed — relay unreachable?')));
    }
  }

  Future<void> _openSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      // Let the sheet ride above the on-screen keyboard when the user taps
      // the paste box (isScrollControlled + viewInsets padding below).
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _SettingsSheet(
          onConnect: (url, token) async {
            final prefs = _prefs;
            if (prefs == null) return false;
            final api = RelayApi(url, token: token);
            try {
              await api.fetchChats();
            } catch (e) {
              messenger.showSnackBar(
                  SnackBar(content: Text('❌ ${describeConnectionError(e)}')));
              return false;
            }
            await prefs.setCredentials(url, token);
            _serverUrl = url;
            _token = token;
            _api = RelayApi(_serverUrl, token: _token);
            await _reload();
            messenger.showSnackBar(
                const SnackBar(content: Text('✅ Connected to your machine')));
            return true;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const HelpDrawer(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 768;
            return Column(
              children: [
                if (wide) _buildDesktopHeader() else _buildMobileHeader(),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _buildChatsTab(),
                      FilesScreen(api: _api, embedded: true),
                      FilesScreen(
                          api: _api, embedded: true, initialTab: 'health'),
                    ],
                  ),
                ),
                if (!wide) _buildBottomNav(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── headers ────────────────────────────────────────────────────────────
  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_rounded, color: gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Hermes Companion',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.geist(
                    fontSize: 20, fontWeight: FontWeight.w600, color: cream)),
          ),
          const SizedBox(width: 8),
          _RelayBadge(connected: _connected, everChecked: _everChecked),
          IconButton(
            tooltip: 'Help & prompts',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.info_outline_rounded, color: sand, size: 20),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: sand, size: 20),
          ),
          const SizedBox(width: 2),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _createChat,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Chat',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/icon/icon.png',
                width: 28, height: 28, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Text('Chats',
              style: GoogleFonts.geist(
                  fontSize: 20, fontWeight: FontWeight.w600, color: cream)),
          const Spacer(),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? green : red,
            ),
          ),
          IconButton(
            tooltip: 'Help & prompts',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.info_outline_rounded, color: sand, size: 20),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: sand, size: 20),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _createChat,
            icon: const Icon(Icons.add_rounded, color: gold, size: 22),
          ),
        ],
      ),
    );
  }

  // ── bottom nav (mobile) ────────────────────────────────────────────────
  Widget _buildBottomNav() {
    Widget item(int index, IconData icon, String label) {
      final active = _tab == index;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? green.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 22,
                    color: active ? gold : sand),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        color: active ? gold : sand)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          item(0, Icons.chat_bubble_rounded, 'Chats'),
          item(1, Icons.folder_open_rounded, 'Files'),
          item(2, Icons.monitor_heart_rounded, 'Health'),
        ],
      ),
    );
  }

  // ── chats tab ──────────────────────────────────────────────────────────
  Widget _buildChatsTab() {
    if (_everChecked == null) {
      return const Center(
          child: CircularProgressIndicator(color: gold, strokeWidth: 2));
    }
    if (!_connected) {
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
              onPressed: _openSettings,
              child:
                  const Text('Check settings', style: TextStyle(color: gold)),
            ),
          ],
        ),
      );
    }
    if (_chats.isEmpty) {
      return const Center(
        child: Text('No chats yet — tap + to start one',
            style: TextStyle(color: sand, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      color: gold,
      backgroundColor: surface,
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _chats.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _buildTile(_chats[i]),
      ),
    );
  }

  Widget _buildTile(ChatInfo chat) {
    final seen = _prefs?.seenFor(chat.id) ?? 0;
    final unread = chat.lastId > seen ? chat.lastId - seen : 0;
    final status = _statuses[chat.id];
    final paused = status?.paused ?? false;
    final tile = ChatTile(
      chat: chat,
      // The main chat is the admin/sync channel — no power toggle on it.
      displayName: chat.isMain ? 'Hermes Admin' : chat.name,
      connected: _connected,
      status: status,
      unread: unread,
      paused: paused,
      onToggle: chat.isMain ? null : () => _togglePaused(chat, paused),
      onTap: () => _openChat(chat),
      onLongPress: chat.isMain ? null : () async {
        if (await _confirmDelete(chat)) await _deleteChat(chat);
      },
    );
    if (chat.isMain) return tile;
    return Dismissible(
      key: ValueKey('chat-${chat.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: redDeep,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: onRed),
      ),
      confirmDismiss: (_) => _confirmDelete(chat),
      onDismissed: (_) => _deleteChat(chat),
      child: tile,
    );
  }

  /// Power toggle: pause/resume the agent session for a chat. When paused
  /// the relay stops that session's CLI, so it uses zero system resources.
  Future<void> _togglePaused(ChatInfo chat, bool paused) async {
    final ok = paused
        ? await _api.resumeChat(chat.id)
        : await _api.pauseChat(chat.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not ${paused ? 'resume' : 'pause'} — relay support missing?')));
      return;
    }
    await _reload();
  }
}

class _RelayBadge extends StatelessWidget {
  const _RelayBadge({required this.connected, required this.everChecked});

  final bool connected;
  final bool? everChecked;

  @override
  Widget build(BuildContext context) {
    final label = everChecked == null
        ? 'Connecting…'
        : connected
            ? 'Relay Online'
            : 'Relay Offline';
    final color = everChecked == null
        ? outline
        : connected
            ? greenBright
            : red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: surfaceLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: connected ? green : red),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

/// Settings bottom sheet: a single pairing-link paste box. The app parses the
/// full `hermes://pair?url=…&token=…` line itself — no manual URL/token entry.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.onConnect});

  /// Validates + saves the connection; returns true on success (the sheet
  /// then closes itself).
  final Future<bool> Function(String url, String token) onConnect;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  final _linkController = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _warnPublicHttp = false;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _linkController.removeListener(_onChanged);
    _linkController.dispose();
    super.dispose();
  }

  void _onChanged() {
    final cfg = parsePairLink(_linkController.text.trim());
    setState(() {
      _warnPublicHttp = cfg != null &&
          cfg.url.startsWith('http://') &&
          !isLanHost(cfg.url);
      _error = null;
    });
  }

  Future<void> _connect() async {
    final cfg = parsePairLink(_linkController.text.trim());
    if (cfg == null) {
      setState(() => _error =
          'That doesn\'t look like a pairing link — paste the full hermes://pair?url=…&token=… line.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.onConnect(cfg.url, cfg.token);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = 'Could not connect — check the link and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      // Scrollable so the whole sheet stays reachable with the keyboard up
      // (the sheet is pushed above the keyboard via viewInsets padding).
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings',
                style: GoogleFonts.geist(
                    fontSize: 22, fontWeight: FontWeight.w600, color: cream)),
            const SizedBox(height: 6),
            const Text(
              'Paste your pairing link here (hermes://pair?url=…&token=…) — '
              'the app saves it and connects. Tunnel URLs change on every '
              'restart, so ask Hermes for a fresh link if this one is old.',
              style: TextStyle(color: sand, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _linkController,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(
                  fontFamily: monoFamily, fontSize: 13, color: cream),
              decoration: InputDecoration(
                hintText: 'hermes://pair?url=…&token=…',
                hintStyle: TextStyle(
                    fontFamily: monoFamily, fontSize: 13, color: outline),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: gold, width: 1.2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            if (_warnPublicHttp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.public_rounded, size: 13, color: gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Public address over plain http — use https:// when '
                        'connecting from the internet.',
                        style: TextStyle(
                            color: gold, fontSize: 11, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('❌ $_error',
                    style: const TextStyle(color: red, fontSize: 12)),
              ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: agentPairingPrompt()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Prompt copied — send it to your agent')));
              },
              icon: const Icon(Icons.copy_rounded, size: 15),
              label: const Text('Copy master prompt',
                  style: TextStyle(color: gold, fontSize: 12.5)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _busy ? null : _connect,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: onPrimary, strokeWidth: 2))
                    : const Icon(Icons.link_rounded, size: 16),
                label: Text(_busy ? 'Connecting…' : 'Connect',
                    style: const TextStyle(color: onPrimary, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
