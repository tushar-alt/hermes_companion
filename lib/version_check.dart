import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'reload_io.dart' if (dart.library.html) 'reload_web.dart' as reload;
import 'theme.dart';

/// Build id injected at build time via `--dart-define=BUILD_ID=git-sha`.
/// Empty on local/native builds (version check is skipped).
const String kBuildId = String.fromEnvironment('BUILD_ID', defaultValue: '');

/// Wraps the app on the web and checks the deployed `build_id.json` against
/// the running bundle. When a newer deploy is detected, a "new version"
/// material banner is shown so long-open tabs can update without hunting for
/// a refresh. No-op on native and in local web builds.
class VersionCheck extends StatefulWidget {
  const VersionCheck({super.key, required this.child, required this.messengerKey});

  final Widget child;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  State<VersionCheck> createState() => _VersionCheckState();
}

class _VersionCheckState extends State<VersionCheck> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && kBuildId.isNotEmpty) {
      // Wait for the first frame so the ScaffoldMessenger is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    try {
      final res = await http
          .get(Uri.parse(
              'build_id.json?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final serverId = data['build_id'] as String? ?? '';
      if (serverId.isNotEmpty && serverId != kBuildId && !_shown) {
        _shown = true;
        if (!mounted) return;
        _showBanner();
      }
    } catch (_) {
      // Offline or relay hiccup — ignore, check again next launch.
    }
  }

  void _showBanner() {
    final messenger = widget.messengerKey.currentState;
    if (messenger == null) return;
    messenger.showMaterialBanner(MaterialBanner(
      backgroundColor: surface,
      leading: const Icon(Icons.system_update_alt_rounded, color: gold),
      content: const Text(
        'A new version is available — reload to see the latest UI.',
        style: TextStyle(color: cream, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: reload.hardReload,
          child: const Text('Reload',
              style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => messenger.hideCurrentMaterialBanner(),
          child: const Text('Later', style: TextStyle(color: sand)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
