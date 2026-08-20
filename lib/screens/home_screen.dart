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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  AppPrefs? _prefs;
  late RelayApi _api;
  String _serverUrl = defaultServerUrl;
  String _token = '';
  bool _connected = false;
  bool? _everChecked;
  List<ChatInfo> _chats = [];
  Map<String, ChatStatus> _statuses = {};
  Timer? _timer;
  bool _booted = false;
  bool _appVisible = true;

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
        pageBuilder: (_, _, _) => ChatScreen(
            chatId: chat.id, chatName: chat.name),
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

  void _openFiles() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, _, _) => FilesScreen(api: _api),
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
                borderSide: BorderSide(color: Color(0x33C9A24B))),
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
            child: const Text('Create', style: TextStyle(color: bg)),
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
            style: FilledButton.styleFrom(backgroundColor: red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
    final urlController = TextEditingController(text: _serverUrl);
    final tokenController = TextEditingController(text: _token);
    final warnPublicHttp =
        _serverUrl.trim().startsWith('http://') && !isLanHost(_serverUrl.trim());
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: GoogleFonts.fraunces(
                      fontSize: 22, fontWeight: FontWeight.w600, color: cream)),
              const SizedBox(height: 18),
              const Text('Server URL',
                  style: TextStyle(color: sand, fontSize: 12)),
              TextField(
                controller: urlController,
                style: const TextStyle(color: cream),
                decoration: const InputDecoration(
                  hintText: 'http://192.168.0.56:8124',
                  hintStyle: TextStyle(color: sand),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0x33C9A24B))),
                  focusedBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: gold)),
                ),
              ),
              if (warnPublicHttp)
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
              const SizedBox(height: 14),
              const Text('Access token',
                  style: TextStyle(color: sand, fontSize: 12)),
              TextField(
                controller: tokenController,
                obscureText: true,
                style: const TextStyle(color: cream),
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0x33C9A24B))),
                  focusedBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: gold)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: agentPairingPrompt()));
                  messenger.showSnackBar(const SnackBar(
                      content:
                          Text('Prompt copied — send it to your agent')));
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Copy master prompt',
                    style: TextStyle(color: gold, fontSize: 12.5)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      final url = normalizeBaseUrl(urlController.text.trim());
                      if (url != urlController.text.trim()) {
                        urlController.text = url;
                      }
                      final api =
                          RelayApi(url, token: tokenController.text.trim());
                      try {
                        await api.fetchChats();
                        messenger.showSnackBar(
                            const SnackBar(content: Text('✅ Connection OK')));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(
                            content:
                                Text('❌ ${describeConnectionError(e)}')));
                      }
                    },
                    child: const Text('Test', style: TextStyle(color: gold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: gold),
                      onPressed: () async {
                        final url = normalizeBaseUrl(urlController.text.trim());
                        if (url != urlController.text.trim()) {
                          urlController.text = url;
                        }
                        await _prefs!.setCredentials(
                            url, tokenController.text.trim());
                        _serverUrl = url;
                        _token = tokenController.text.trim();
                        _api = RelayApi(_serverUrl, token: _token);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        await _reload();
                      },
                      child:
                          const Text('Save', style: TextStyle(color: bg)),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createChat,
        backgroundColor: gold,
        elevation: 8,
        child: const Icon(Icons.add_rounded, color: bg, size: 26),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg, bg.withValues(alpha: 0.0)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: goldGradient,
              boxShadow: [BoxShadow(color: Color(0x55C9A24B), blurRadius: 16)],
            ),
            child: const Center(
              child: Text('⚕',
                  style: TextStyle(
                      color: bg, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hermes',
                    style: GoogleFonts.fraunces(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: cream)),
                Text(
                  _everChecked == null
                      ? 'connecting…'
                      : _connected
                          ? 'online'
                          : 'offline — relay unreachable',
                  style: TextStyle(
                    fontSize: 12,
                    color: _everChecked == null
                        ? sand
                        : _connected
                            ? green
                            : red,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Help & prompts',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.info_outline_rounded, color: sand, size: 22),
          ),
          IconButton(
            tooltip: 'Files',
            onPressed: _openFiles,
            icon: const Icon(Icons.folder_outlined, color: sand, size: 22),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, color: sand, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
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
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
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
          color: red,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
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
