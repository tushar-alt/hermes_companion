import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'agent_prompt.dart';
import 'api.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets/help_drawer.dart';

/// Connection settings parsed from the pairing link an agent generates.
class PairConfig {
  const PairConfig(this.url, this.token);

  final String url;
  final String token;
}

/// Accepts several forgiving input shapes:
///   `hermes://pair?url=<urlencoded>&token=<token>`  (agent-generated)
///   `http://192.168.0.56:8124`                      (bare relay URL)
///   `http://...|token`                              (URL|token)
///
/// Whitespace is stripped everywhere and the URL is normalized, because chat
/// apps wrap/space links and a stray space in the host breaks dart:io.
PairConfig? parsePairLink(String input) {
  final s = input.replaceAll(RegExp(r'\s+'), '').trim();
  if (s.isEmpty) return null;
  final uri = Uri.tryParse(s);
  if (uri != null && uri.scheme == 'hermes') {
    final url = normalizeBaseUrl(uri.queryParameters['url']?.trim() ?? '');
    final token = uri.queryParameters['token']?.trim() ?? '';
    if (url.isEmpty) return null;
    return PairConfig(url, token);
  }
  // `url|token` — checked before the bare-URL branch so a pasted
  // "http://host:port|token" splits correctly.
  if (s.contains('|')) {
    final parts = s.split('|');
    final url = normalizeBaseUrl(parts.first.trim());
    final token = parts.sublist(1).join('|').trim();
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return PairConfig(url, token);
    }
  }
  if (s.startsWith('http://') || s.startsWith('https://')) {
    return PairConfig(normalizeBaseUrl(s), '');
  }
  return null;
}

/// First-run welcome + connect screen. Shown only until the user has paired.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _linkController = TextEditingController();
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _testing = false;
  bool _testedOk = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    // Keep the public-http warning live while the user types a URL.
    _urlController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _copyAgentPrompt() async {
    await Clipboard.setData(ClipboardData(text: agentPairingPrompt()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Master prompt copied — send it to your agent')));
  }

  Future<void> _useLink() async {
    final cfg = parsePairLink(_linkController.text);
    if (cfg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('That doesn\'t look like a pairing link')));
      return;
    }
    _urlController.text = cfg.url;
    _tokenController.text = cfg.token;
    await _test();
  }

  Future<void> _test() async {
    final raw = _urlController.text.trim();
    final url = normalizeBaseUrl(raw);
    if (url != raw) _urlController.text = url; // show the cleaned URL
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a server URL')));
      return;
    }
    setState(() {
      _testing = true;
      _testedOk = false;
    });
    final api = RelayApi(url, token: _tokenController.text.trim());
    var ok = false;
    var error = '';
    try {
      await api.fetchChats();
      ok = true;
    } catch (e) {
      ok = false;
      error = describeConnectionError(e);
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testedOk = ok;
      _lastError = ok ? null : error;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✅ Connected to your machine' : '❌ $error')));
  }

  Future<void> _finish() async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await AppPrefs.load();
    await prefs.setCredentials(normalizeBaseUrl(_urlController.text.trim()),
        _tokenController.text.trim());
    await prefs.markOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
    // First connect: auto-copy the master prompt so the user can immediately
    // hand it to Hermes and finish the setup (relay, public URL, sessions).
    await Clipboard.setData(ClipboardData(text: agentPairingPrompt()));
    messenger.showSnackBar(const SnackBar(
        content: Text('Master prompt copied — send it to Hermes to finish setup')));
  }

  Future<void> _skip() async {
    final prefs = await AppPrefs.load();
    await prefs.markOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const HelpDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: goldGradient,
                    boxShadow: [
                      BoxShadow(color: Color(0x55C9A24B), blurRadius: 28),
                    ],
                  ),
                  child: const Center(
                    child: Text('⚕',
                        style: TextStyle(
                            color: bg,
                            fontSize: 38,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Text('Welcome to Hermes Companion',
                  style: GoogleFonts.fraunces(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: cream)),
              const SizedBox(height: 8),
              const Text(
                'A private chat with your Hermes agent, running on your own '
                'machine. It answers, works while you sleep, and pings you '
                'when it has news.',
                style: TextStyle(color: sand, fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 26),
              const Text('Pair with your agent',
                  style: TextStyle(
                      color: sand,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: gold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Don\'t have a link yet?',
                        style: GoogleFonts.fraunces(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cream)),
                    const SizedBox(height: 4),
                    const Text(
                      'Copy this one master prompt and send it to Hermes — it '
                      'sets up the whole relay (reachable from anywhere, with '
                      'session power toggles), then replies with ONLY a '
                      'pairing link, which you paste below.',
                      style: TextStyle(color: sand, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _copyAgentPrompt,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy master prompt'),
                      style:
                          OutlinedButton.styleFrom(foregroundColor: gold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33C9A24B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ask your agent for a pairing link (see the README — '
                      'it knows how to make one). Paste it here:',
                      style: TextStyle(color: cream, fontSize: 12.5, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _linkController,
                      style: const TextStyle(color: cream, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'hermes://pair?url=…&token=…',
                        hintStyle: const TextStyle(color: sand, fontSize: 13),
                        filled: true,
                        fillColor: ink2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _testing ? null : _useLink,
                        style:
                            FilledButton.styleFrom(backgroundColor: gold),
                        icon: const Icon(Icons.link_rounded, size: 16),
                        label: const Text('Use link',
                            style: TextStyle(color: bg, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('— or enter the details manually —',
                    style: TextStyle(color: sand.withValues(alpha: 0.7), fontSize: 11.5)),
              ),
              const SizedBox(height: 14),
              const Text('Server URL',
                  style: TextStyle(color: sand, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
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
              if (_urlController.text.trim().isNotEmpty &&
                  _urlController.text.trim().startsWith('http://') &&
                  !isLanHost(_urlController.text.trim()))
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
              const SizedBox(height: 12),
              const Text('Access token (optional)',
                  style: TextStyle(color: sand, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _tokenController,
                obscureText: true,
                style: const TextStyle(color: cream),
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0x33C9A24B))),
                  focusedBorder:
                      UnderlineInputBorder(borderSide: BorderSide(color: gold)),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _testing ? null : _test,
                    child: _testing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: gold, strokeWidth: 2))
                        : const Text('Test connection',
                            style: TextStyle(color: gold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _testedOk ? gold : ink2),
                      onPressed: _testedOk ? _finish : null,
                      child: const Text('Connect',
                          style: TextStyle(
                              color: bg,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('❌ $_lastError',
                      style: const TextStyle(color: red, fontSize: 12)),
                ),
              Center(
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip for now',
                      style: TextStyle(color: sand, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: 'Help & prompts',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: const Icon(Icons.info_outline_rounded, color: sand, size: 22),
          ),
        ),
      ],
    ),
  ),
  );
  }
}
