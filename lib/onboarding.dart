import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'agent_prompt.dart';
import 'api.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets/help_drawer.dart';

/// First-run welcome + connect screen. Shown only until the user has paired.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _linkController = TextEditingController();
  bool _testing = false;
  String? _lastError;
  bool _warnPublicHttp = false;

  @override
  void initState() {
    super.initState();
    // Keep the public-http warning live while the user types/pastes a link.
    _linkController.addListener(() {
      if (!mounted) return;
      setState(() {
        final cfg = parsePairLink(_linkController.text.trim());
        _warnPublicHttp = cfg != null &&
            cfg.url.startsWith('http://') &&
            !isLanHost(cfg.url);
        _lastError = null;
      });
    });
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _copyAgentPrompt() async {
    await Clipboard.setData(ClipboardData(text: agentPairingPrompt()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Master prompt copied — send it to your agent')));
  }

  /// Parse the pasted pairing link, test the connection, and on success save
  /// the credentials and enter the app — all in one action.
  Future<void> _useLink() async {
    final cfg = parsePairLink(_linkController.text);
    if (cfg == null) {
      setState(() => _lastError =
          'That doesn\'t look like a pairing link — paste the full hermes://pair?url=…&token=… line.');
      return;
    }
    setState(() {
      _testing = true;
      _lastError = null;
    });
    final api = RelayApi(cfg.url, token: cfg.token);
    var ok = false;
    var error = '';
    try {
      await api.fetchChats();
      ok = true;
    } catch (e) {
      error = describeConnectionError(e);
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _testing = false;
        _lastError = error;
      });
      return;
    }
    // Connected — save and enter the app.
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await AppPrefs.load();
    await prefs.setCredentials(cfg.url, cfg.token);
    await prefs.markOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
    // First connect: auto-copy the master prompt so the user can immediately
    // hand it to Hermes and finish the setup (relay, public URL, sessions).
    await Clipboard.setData(ClipboardData(text: agentPairingPrompt()));
    messenger.showSnackBar(const SnackBar(
        content: Text(
            '✅ Connected — master prompt copied, send it to Hermes to finish setup')));
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
                        icon: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    color: bg, strokeWidth: 2))
                            : const Icon(Icons.link_rounded, size: 16),
                        label: Text(_testing ? 'Connecting…' : 'Connect',
                            style: const TextStyle(
                                color: bg,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_lastError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: red.withValues(alpha: 0.4)),
                  ),
                  child: Text('❌ $_lastError',
                      style: const TextStyle(color: red, fontSize: 12)),
                ),
              if (_warnPublicHttp)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
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
              const SizedBox(height: 22),
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
