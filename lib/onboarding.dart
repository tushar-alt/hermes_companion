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
///
/// Matches the "Pairing & Setup" design: centered logo + title, a single
/// "Connect to Relay" card with one paste box (accepts the hermes://pair link,
/// `url#token`, `url|token` or a bare URL) and a "First Time Setup?" card that
/// copies the master prompt.
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
  String _hint = 'Waiting for valid token…';
  bool _hintOk = false;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(() {
      if (!mounted) return;
      setState(() {
        _lastError = null;
        final cfg = parsePairLink(_linkController.text.trim());
        if (_linkController.text.trim().isEmpty) {
          _hint = 'Waiting for valid token…';
          _hintOk = false;
        } else if (cfg != null) {
          _hint = 'Valid format detected. Ready to verify.';
          _hintOk = true;
        } else {
          _hint = 'Invalid format. Expected: hermes://pair?url=…&token=…';
          _hintOk = false;
        }
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
        content: Text('Bootstrap prompt copied — send it to your agent')));
  }

  /// Parse the pasted pairing link, test the connection, and on success save
  /// the credentials and enter the app — all in one action.
  Future<void> _connect() async {
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
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: logo, title, self-hosted badge.
                      Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              color: surface,
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x0D58A6FF),
                                    blurRadius: 20),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text('Hermes Companion',
                              style: GoogleFonts.geist(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: cream,
                                  letterSpacing: -0.02)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: borderColor),
                              color: surface,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: green,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('Self-Hosted & Private',
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        letterSpacing: 0.05,
                                        fontWeight: FontWeight.w700,
                                        color: sand)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Card 1: Connect to Relay.
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Connect to Relay',
                                style: GoogleFonts.geist(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: cream)),
                            const SizedBox(height: 16),
                            Text('PAIRING LINK',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    letterSpacing: 0.05,
                                    color: sand)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _linkController,
                              maxLines: 2,
                              minLines: 1,
                              style: TextStyle(
                                  fontFamily: monoFamily,
                                  fontSize: 13,
                                  color: cream),
                              decoration: InputDecoration(
                                hintText: 'hermes://pair?url=…&token=…',
                                hintStyle: TextStyle(
                                    fontFamily: monoFamily,
                                    fontSize: 13,
                                    color: outline),
                                filled: true,
                                fillColor: bg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: gold, width: 1.2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  _hintOk
                                      ? Icons.wifi_tethering
                                      : Icons.wifi_tethering,
                                  size: 16,
                                  color: _hintOk
                                      ? greenBright
                                      : _linkController.text.trim().isNotEmpty
                                          ? red
                                          : outline,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(_hint,
                                      style: TextStyle(
                                          fontFamily: monoFamily,
                                          fontSize: 11,
                                          color: _hintOk
                                              ? greenBright
                                              : _linkController.text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? red
                                                  : outline)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: gold,
                                  foregroundColor: onPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _testing ? null : _connect,
                                icon: _testing
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            color: onPrimary, strokeWidth: 2))
                                    : const Icon(Icons.arrow_forward_rounded,
                                        size: 18),
                                label: Text(
                                    _testing ? 'Connecting…' : 'Verify & Connect',
                                    style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500)),
                              ),
                            ),
                            if (_lastError != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: redDeep.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: red.withValues(alpha: 0.4)),
                                ),
                                child: Text('$_lastError',
                                    style: const TextStyle(
                                        color: onRed, fontSize: 12)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: First time setup.
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.terminal_rounded,
                                    color: gold, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('First Time Setup?',
                                          style: GoogleFonts.inter(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: cream)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Run the bootstrap script on your local '
                                        'machine to initialize the agent and '
                                        'generate a secure pairing link.',
                                        style: const TextStyle(
                                            color: sand,
                                            fontSize: 13,
                                            height: 1.45),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _copyAgentPrompt,
                                icon: const Icon(Icons.content_copy,
                                    size: 18, color: sand),
                                label: const Text('Copy Bootstrap Prompt',
                                    style:
                                        TextStyle(color: cream, fontSize: 14)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cream,
                                  side: const BorderSide(color: borderColor),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Footer.
                      Center(
                        child: Text(
                          'Zero telemetry. Bearer tokens and history stay on your hardware.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: monoFamily,
                              fontSize: 11,
                              color: outline.withValues(alpha: 0.7)),
                        ),
                      ),
                      const SizedBox(height: 8),
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
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Help & prompts',
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.info_outline_rounded,
                    color: sand, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
