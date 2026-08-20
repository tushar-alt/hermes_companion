import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api.dart';
import '../file_bytes_io.dart' if (dart.library.html) '../file_bytes_web.dart'
    as fb;
import '../models.dart';
import '../notifications.dart'
    if (dart.library.html) '../notifications_web.dart' as notifications;
import '../storage.dart';
import '../theme.dart';
import '../widgets/icon_avatar.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_bubble.dart';
import 'files_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key, required this.chatId, required this.chatName, this.embedded = false});

  final String chatId;
  final String chatName;

  /// True when rendered inside the desktop dual-pane shell (no back button;
  /// the chat list stays visible on the left).
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  AppPrefs? _prefs;
  late RelayApi _api;
  bool _connected = false;
  bool? _everChecked;
  final List<ChatMessage> _messages = [];
  int _lastId = 0;
  bool _pending = false;
  bool _isForeground = true;
  bool _flushing = false;
  bool _polling = false;
  ChatStatus? _status;
  final List<QueuedMessage> _queue = [];
  final List<Attachment> _attachments = [];
  final Set<int> _failedIds = {};
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();
  Timer? _timer;
  int _optimisticSeq = 0;
  bool _booted = false;
  bool _showCacheBanner = false;
  bool _showJumpButton = false;

  /// True while the user is looking at the newest message (within 300px of
  /// the bottom of the reversed list). Once the user scrolls up to read
  /// history this flips false, and incoming messages must not yank the list
  /// back down until they scroll back to the bottom (or tap the jump button).
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _inputFocus.addListener(_onInputFocus);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// WhatsApp behaviour: when the user taps the input box and the keyboard
  /// opens, keep the last message visible above it — but only if they haven't
  /// scrolled up to read history (don't yank them away from it).
  void _onInputFocus() {
    if (_inputFocus.hasFocus && _atBottom) _scrollToBottom();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // The list is reversed, so offset 0 is the newest message.
    final atBottom = _scrollController.position.pixels < 300;
    if (atBottom == _atBottom && _showJumpButton == !atBottom) return;
    setState(() {
      _atBottom = atBottom;
      _showJumpButton = !atBottom;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_booted) return;
    _isForeground = state == AppLifecycleState.resumed;
    _prefs?.setAppForeground(_isForeground);
    if (_isForeground) _poll();
  }

  // ── busy detection ────────────────────────────────────────────────────
  // The relay's /api/status is authoritative: the agent is "busy" only while
  // it reports running. The old heuristic ("last message is yours") queued
  // everything you typed right after sending — messages seemed to vanish.
  bool get _heuristicBusy =>
      _messages.isNotEmpty && _messages.last.isUser && !_pending;

  bool get _agentBusy =>
      (_status?.isRunning ?? _heuristicBusy) && !_flushing;

  bool _isFailed(ChatMessage m) => m.id < 0 && _failedIds.contains(m.id);

  /// The "thinking…" indicator must stay visible from the moment a message
  /// is sent until the agent's reply actually arrives. So: while our own
  /// send is in flight, while the agent reports running, or whenever the
  /// last message is an unanswered one from us (a failed send does not
  /// count as awaiting a reply).
  bool get _showTyping =>
      _pending ||
      _agentBusy ||
      (_messages.isNotEmpty &&
          _messages.last.isUser &&
          !_isFailed(_messages.last));

  Future<void> _boot() async {
    _prefs = await AppPrefs.load();
    _api = RelayApi(_prefs!.serverUrl, token: _prefs!.token);
    // Restore the persistent outbox — queued messages survive restarts.
    setState(() => _queue.addAll(_prefs!.outboxFor(widget.chatId)));
    await _refreshStatus();
    await _initialLoad();
    _booted = true;
    _schedulePoll();
    // Anything left queued while the agent is idle can go out right away.
    if (!_agentBusy && _queue.isNotEmpty && !_flushing) _flushQueue();
  }

  Future<void> _refreshStatus() async {
    try {
      final st = await _api.fetchStatus();
      if (!mounted) return;
      setState(() => _status = st[widget.chatId]);
    } catch (_) {
      // best-effort — the heuristic fallback covers a missing status endpoint
    }
  }

  void _schedulePoll() {
    _timer?.cancel();
    final delay = _agentBusy
        ? const Duration(seconds: 2)
        : const Duration(seconds: 6);
    _timer = Timer(delay, () async {
      await _poll();
      if (mounted) _schedulePoll();
    });
  }

  Future<void> _initialLoad() async {
    try {
      final page = await _api.fetchMessages(0, chatId: widget.chatId);
      if (!mounted) return;
      setState(() {
        // Keep optimistic (negative-id) bubbles — a message sent while this
        // load was in flight must not vanish.
        _messages.removeWhere((m) => m.id >= 0);
        _messages.addAll(page.messages);
        _lastId = page.lastId;
        _connected = true;
        _everChecked = true;
        _showCacheBanner = false;
      });
      await _prefs!.setLastId(widget.chatId, _lastId);
      await _prefs!.setSeen(widget.chatId, _lastId);
      await _prefs!.setCache(widget.chatId, page.messages);
      _ensureAtBottom();
    } catch (_) {
      // Offline: fall back to the last cached page so the chat is readable.
      final cached = _prefs?.cachedMessagesFor(widget.chatId);
      if (!mounted) return;
      setState(() {
        if (cached != null && cached.isNotEmpty) {
          _messages
            ..clear()
            ..addAll(cached);
          _lastId = _prefs!.lastIdFor(widget.chatId);
          _showCacheBanner = true;
        }
        _connected = false;
        _everChecked = true;
      });
      _ensureAtBottom();
    }
  }

  /// Jump to the newest message. Tries again after layout settles so a late
  /// content size change can't leave the list stranded mid-history.
  Future<void> _ensureAtBottom() async {
    _scrollToBottom(instant: true);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _scrollToBottom(instant: true);
  }

  /// Merge server messages without duplicating anything already shown.
  void _mergeMessages(List<ChatMessage> incoming) {
    final known = _messages.where((m) => m.id >= 0).map((m) => m.id).toSet();
    final fresh = <ChatMessage>[];
    for (final m in incoming) {
      if (m.id <= _lastId || known.contains(m.id)) continue;
      known.add(m.id);
      fresh.add(m);
    }
    if (fresh.isEmpty) {
      if (incoming.isNotEmpty && incoming.last.id > _lastId) {
        _lastId = incoming.last.id;
      }
      return;
    }
    // Count optimistic bubbles per text, so repeated identical messages only
    // remove as many optimistic bubbles as the server actually confirmed.
    final optByText = <String, int>{};
    for (final m in _messages) {
      if (m.id < 0 && m.isUser) {
        optByText[m.text] = (optByText[m.text] ?? 0) + 1;
      }
    }
    final userTexts = fresh.where((m) => m.isUser).map((m) => m.text).toList();
    for (final t in userTexts) {
      final confirmed = userTexts.where((x) => x == t).length;
      final opt = optByText[t] ?? 0;
      var toRemove = confirmed < opt ? confirmed : opt;
      _messages.removeWhere((m) {
        if (toRemove <= 0) return false;
        if (m.id < 0 && m.isUser && m.text == t) {
          toRemove--;
          return true;
        }
        return false;
      });
    }
    _messages.addAll(fresh);
    if (fresh.last.id > _lastId) _lastId = fresh.last.id;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final page = await _api.fetchMessages(_lastId, chatId: widget.chatId);
      if (!mounted) return;
      setState(() {
        _connected = true;
        if (page.messages.isNotEmpty) {
          _mergeMessages(page.messages);
        }
        _showCacheBanner = false;
      });
      await _prefs!.setLastId(widget.chatId, _lastId);
      if (page.messages.isNotEmpty) {
        await _prefs!.setLastActive(
            widget.chatId, DateTime.now().millisecondsSinceEpoch);
      }
      if (_isForeground) {
        await _prefs!.setSeen(widget.chatId, _lastId);
      } else {
        final replies =
            page.messages.where((m) => !m.isUser && m.text.isNotEmpty);
        if (replies.isNotEmpty) {
          await notifications.showHermesNotification(
              '${widget.chatName} 💬', _cleanPreview(replies.last.text));
        }
      }
      // Cache for offline reading (keep the tail).
      final keep = _messages.length > 400
          ? _messages.sublist(_messages.length - 400)
          : _messages;
      await _prefs!.setCache(
          widget.chatId, keep.where((m) => m.id >= 0).toList());
      // Refresh the authoritative busy flag, then auto-flush if the agent
      // became free while messages were waiting.
      await _refreshStatus();
      if (!_agentBusy && _queue.isNotEmpty && !_flushing) {
        _flushQueue();
      }
      // Stay glued to the newest message only while the user is already at
      // the bottom; if they scrolled up, incoming messages must not yank the
      // list back down (the jump-to-bottom button gets them back).
      if (_atBottom) _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _connected = false);
    } finally {
      _polling = false;
    }
  }

  Future<void> _persistQueue() =>
      _prefs!.setOutbox(widget.chatId, List.of(_queue));

  Future<void> _send() async {
    final text = _controller.text.trim();
    final atts = List<Attachment>.of(_attachments);
    if (text.isEmpty && atts.isEmpty) return;
    _controller.clear();
    if (_agentBusy) {
      if (_queue.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Queue full (5) — hit “send now” or wait a sec')));
        return;
      }
      setState(() {
        _queue.add(QueuedMessage(text, atts));
        _attachments.clear();
      });
      await _persistQueue();
      return;
    }
    setState(() => _attachments.clear());
    await _sendRaw(text, atts);
  }

  /// Upload attachments (if any) and post the message. Returns success.
  Future<bool> _sendRaw(String text, List<Attachment> atts) async {
    List<String> serverMedia = [];
    // Attachments whose local file vanished (e.g. cache cleanup) are
    // dropped instead of failing the whole send. On the web the picked
    // bytes live in memory, so they cannot "vanish".
    final liveAtts = <Attachment>[];
    for (final att in atts) {
      if (await fb.attachmentBytes(att) != null) {
        liveAtts.add(att);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Attachment “${att.name}” is gone — skipped')));
      }
    }
    try {
      for (final att in liveAtts) {
        final bytes = await fb.attachmentBytes(att);
        if (bytes == null) continue;
        final p = await _api.uploadFile(widget.chatId, att.name, bytes);
        serverMedia.add(p);
      }
    } catch (_) {
      if (!mounted) return false;
      setState(() => _connected = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed — check relay')));
      return false;
    }
    return _post(text, serverMedia);
  }

  /// Post a message with an optimistic bubble. On failure the bubble is kept
  /// and marked so the user can tap to retry — it never silently vanishes.
  Future<bool> _post(String text, List<String> serverMedia) async {
    final optimistic = ChatMessage(
      id: -(_optimisticSeq++ + 1),
      role: 'user',
      text: text,
      ts: DateTime.now().millisecondsSinceEpoch / 1000,
      media: serverMedia,
    );
    setState(() {
      _pending = true;
      _messages.add(optimistic);
    });
    _scrollToBottom();
    var ok = false;
    try {
      await _api.send(text, chatId: widget.chatId, media: serverMedia);
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return ok;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _pending = false;
      if (!ok) {
        _connected = false;
        _failedIds.add(optimistic.id);
      }
    });
    if (ok) {
      await _prefs?.setLastActive(
          widget.chatId, DateTime.now().millisecondsSinceEpoch);
    }
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Send failed — tap the message to retry')));
    }
    _schedulePoll();
    return ok;
  }

  Future<void> _retry(ChatMessage m) async {
    setState(() => _failedIds.remove(m.id));
    // The optimistic bubble kept the server media paths, so resend as-is.
    await _post(m.text, m.media);
  }

  Future<void> _flushQueue() async {
    if (_queue.isEmpty || _flushing) return;
    _flushing = true;
    final items = List<QueuedMessage>.of(_queue);
    setState(() => _queue.clear());
    await _persistQueue();
    try {
      for (final item in items) {
        final ok = await _sendRaw(item.text, item.media);
        if (!ok) break; // the failed bubble stays visible; retry manually
      }
    } finally {
      _flushing = false;
    }
    if (mounted) _schedulePoll();
  }

  Future<void> _pickAttachment() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final f = files.single;
    final localPath = f.path;
    if (localPath != null) {
      // Device build: keep the local file path, read it when sending.
      setState(() {
        _attachments.add(Attachment(localPath, f.name));
      });
    } else {
      // Web build: the picker hands back a blob/data URI — read its bytes.
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        _attachments.add(Attachment('', f.name, bytes: bytes));
      });
    }
  }

  Future<void> _openInfoSheet() async {
    ChatStatus? fresh = _status;
    try {
      final st = await _api.fetchStatus();
      fresh = st[widget.chatId];
      if (mounted) setState(() => _status = fresh);
    } catch (_) {}
    if (!mounted) return;
    final running = fresh?.isRunning == true;
    final since = running && fresh!.since > 0
        ? DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(
                (fresh.since * 1000).round()))
            .inSeconds
            .toString()
        : null;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final messenger = ScaffoldMessenger.of(context);
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final muted = _prefs?.mutedFor(widget.chatId) ?? false;
              return Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconAvatar(seed: widget.chatId, size: 38),
                        const SizedBox(width: 12),
                        Text(widget.chatName,
                            style: GoogleFonts.geist(
                                fontSize: 19, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _infoRow(
                        'Status',
                        running
                            ? 'RUNNING'
                            : fresh?.paused == true
                                ? 'PAUSED'
                                : 'IDLE',
                        color: running
                            ? gold
                            : fresh?.paused == true
                                ? red
                                : green),
                    if (running && since != null)
                      _infoRow('Working for', '$since s', color: gold),
                    if (fresh != null && fresh.detail.isNotEmpty)
                      _infoRow('Activity', fresh.detail),
                    _infoRow('Chat ID', widget.chatId),
                    _infoRow('Messages', '${_messages.length}'),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: muted,
                      activeThumbColor: gold,
                      activeTrackColor: gold.withValues(alpha: 0.5),
                      title: const Text('Mute notifications',
                          style: TextStyle(color: cream, fontSize: 13.5)),
                      subtitle: const Text('No pings from this chat',
                          style: TextStyle(color: sand, fontSize: 11.5)),
                      onChanged: (v) async {
                        await _prefs!.setMuted(widget.chatId, v);
                        if (mounted) {
                          setSheetState(() {});
                          messenger.showSnackBar(SnackBar(
                              content: Text(v ? '🔕 Muted' : '🔔 Unmuted')));
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: sand, fontSize: 12.5))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: color ?? cream,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      // Reversed list: 0 is the bottom (newest message).
      if (instant) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _cleanPreview(String text) {
    var t = text.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');
    t = t.replaceAll(RegExp(r'[#>*\-]\s?'), '').trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 180 ? '${t.substring(0, 180)}…' : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // resizeToAvoidBottomInset defaults to true: when the keyboard opens the
      // message list shrinks so the newest message stays visible above it,
      // exactly like WhatsApp.
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_showCacheBanner) _buildCacheBanner(),
            if (_status?.paused == true) _buildPausedBanner(),
            Expanded(child: _buildMessages()),
            if (_attachments.isNotEmpty) _buildAttachmentBar(),
            if (_queue.isNotEmpty) _buildQueueBar(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: ink2,
      child: const Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 13, color: sand),
          SizedBox(width: 6),
          Text('Offline — showing last cached messages',
              style: TextStyle(color: sand, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPausedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 14, right: 6),
      color: red.withValues(alpha: 0.14),
      child: Row(
        children: [
          const Icon(Icons.power_settings_new_rounded, size: 13, color: red),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Session paused — agent is asleep',
                style: TextStyle(color: red, fontSize: 11)),
          ),
          TextButton(
            onPressed: _resumeSession,
            child: const Text('Resume',
                style: TextStyle(
                    color: red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeSession() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _api.resumeChat(widget.chatId);
    if (!mounted) return;
    if (ok) {
      await _refreshStatus();
      messenger.showSnackBar(
          const SnackBar(content: Text('✅ Session resumed')));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not resume — relay support missing?')));
    }
  }

  /// Pause/resume this chat's agent session (the app-bar power action).
  Future<void> _togglePause() async {
    final paused = _status?.paused == true;
    final messenger = ScaffoldMessenger.of(context);
    final ok = paused
        ? await _api.resumeChat(widget.chatId)
        : await _api.pauseChat(widget.chatId);
    if (!mounted) return;
    if (ok) {
      await _refreshStatus();
      messenger.showSnackBar(SnackBar(
          content: Text(paused ? '✅ Session resumed' : '⏸ Session paused')));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('Could not toggle — relay support missing?')));
    }
  }

  /// Delete this chat everywhere (relay + local state), then leave.
  Future<void> _deleteSession() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?', style: TextStyle(fontSize: 17)),
        content: Text(
            '“${widget.chatName}” will be terminated everywhere: the agent '
            'session stops, and the conversation and its files are removed.',
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
    if (confirmed != true || !mounted) return;
    final ok = await _api.deleteChat(widget.chatId);
    if (!mounted) return;
    if (ok) {
      final prefs = await AppPrefs.load();
      await prefs.clearChat(widget.chatId);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
          const SnackBar(content: Text('Chat deleted')));
    } else {
      messenger.showSnackBar(const SnackBar(
          content: Text('Delete failed — relay unreachable?')));
    }
  }

  void _openFiles() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => FilesScreen(api: _api)));
  }

  Widget _buildAppBar() {
    final isMain = widget.chatId == 'main';
    final running = _status?.isRunning == true;
    final paused = _status?.paused == true;
    final statusLabel = _everChecked == null
        ? 'Connecting…'
        : !_connected
            ? 'Offline — relay unreachable'
            : paused
                ? 'Paused'
                : running
                    ? 'Running (PID Active)'
                    : 'Idle';
    final statusColor = paused
        ? red
        : running
            ? greenBright
            : _everChecked == null
                ? outline
                : _connected
                    ? sand
                    : red;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: sand, size: 18),
            ),
          IconAvatar(
              seed: widget.chatId, size: 36, statusActive: !paused),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.geist(
                        fontSize: 16, fontWeight: FontWeight.w600, color: cream)),
                const SizedBox(height: 2),
                Text(statusLabel,
                    style: TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ],
            ),
          ),
          IconButton(
            tooltip: paused ? 'Resume session' : 'Pause session',
            onPressed: _togglePause,
            icon: Icon(paused ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
                color: paused ? red : gold, size: 22),
          ),
          IconButton(
            tooltip: 'Files',
            onPressed: _openFiles,
            icon: const Icon(Icons.folder_shared_rounded, color: sand, size: 20),
          ),
          if (!isMain)
            IconButton(
              tooltip: 'Delete chat',
              onPressed: _deleteSession,
              icon: const Icon(Icons.delete_outline_rounded, color: red, size: 20),
            ),
          IconButton(
            tooltip: 'Status',
            onPressed: _openInfoSheet,
            icon: const Icon(Icons.info_outline_rounded, color: sand, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Stack(
      children: [
        // Reversed list: index 0 is the newest message (bottom), so the chat
        // always opens at the latest message and stays there when the
        // keyboard opens — exactly like WhatsApp.
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          itemCount: _messages.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return _showTyping
                  ? TypingBubble(seed: widget.chatId)
                  : const SizedBox.shrink();
            }
            final m = _messages[_messages.length - i];
            final isFailed = m.id < 0 && _failedIds.contains(m.id);
            return MessageBubble(
              message: m,
              baseUrl: _api.baseUrl,
              token: _api.token,
              seed: widget.chatId,
              failed: isFailed,
              onRetry: isFailed ? () => _retry(m) : null,
            );
          },
        ),
        if (_showJumpButton)
          Positioned(
            right: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'jump-bottom-${widget.chatId}',
              backgroundColor: surface,
              elevation: 4,
              onPressed: _scrollToBottom,
              child: const Icon(Icons.arrow_downward_rounded,
                  color: gold, size: 18),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33C9A24B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 15, color: gold),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              _attachments.map((a) => a.name).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: cream, fontSize: 11.5),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _attachments.clear()),
            icon: const Icon(Icons.close_rounded, color: sand, size: 16),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueBar() {
    final first = _queue.first;
    final preview = first.text.isEmpty
        ? (first.media.isNotEmpty ? '📎 attachment' : '…')
        : (first.text.length > 22
            ? '${first.text.substring(0, 22)}…'
            : first.text);
    final label = _queue.length > 1
        ? '${_queue.length} queued · "$preview" +${_queue.length - 1}'
        : '1 queued · "$preview"';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 15, color: gold),
          const SizedBox(width: 7),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: cream, fontSize: 11)),
          ),
          TextButton.icon(
            onPressed: _flushing ? null : _flushQueue,
            icon: const Icon(Icons.bolt_rounded, size: 15, color: bg),
            label: const Text('Send now',
                style: TextStyle(
                    color: bg, fontSize: 11, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(
              backgroundColor: gold,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: const BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.add_rounded, color: gold, size: 24),
                tooltip: 'Attach file',
              ),
              Expanded(
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: 42, maxHeight: 120),
                  decoration: BoxDecoration(
                    color: ink2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 4,
                    style: const TextStyle(color: cream, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _pending ? 'sending…' : 'Message Hermes…',
                      hintStyle: const TextStyle(color: sand, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      suffixIcon: _pending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: gold, strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: goldGradient,
                    boxShadow: const [
                      BoxShadow(color: Color(0x3358A6FF), blurRadius: 12),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: onPrimary, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _connected ? green : red,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _connected ? 'RELAY CONNECTED' : 'RELAY DISCONNECTED',
                style: TextStyle(
                    fontFamily: monoFamily,
                    fontSize: 10,
                    letterSpacing: 0.05,
                    color: _connected ? sand : red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
