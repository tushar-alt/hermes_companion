import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../prompts.dart';
import '../theme.dart';

/// Side panel opened by the "i" button. Folders of copyable scripts —
/// most importantly "Prompts", so the user can grab a prompt and send it to
/// their agent without hunting for the README.
class HelpDrawer extends StatelessWidget {
  const HelpDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: surface,
      width: math.min(MediaQuery.sizeOf(context).width * 0.85, 340),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: goldGradient,
                    ),
                    child: const Center(
                      child: Text('⚕',
                          style: TextStyle(
                              color: bg,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Hermes Companion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cream)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Help & prompts',
                  style: TextStyle(color: sand, fontSize: 12)),
            ),
            const Divider(color: Color(0x22C9A24B), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4),
                children: [
                  for (final folder in promptFolders)
                    _FolderTile(folder: folder),
                ],
              ),
            ),
            const Divider(color: Color(0x22C9A24B), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Full setup guide lives in the repo README — hand it to your '
                'agent and it will set everything up.',
                style: const TextStyle(color: sand, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});

  final PromptFolder folder;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.folder_outlined, color: gold, size: 20),
        title: Text(folder.name,
            style: const TextStyle(
                color: cream, fontSize: 14, fontWeight: FontWeight.w600)),
        iconColor: gold,
        collapsedIconColor: sand,
        children: [
          for (final item in folder.items) _ScriptRow(item: item),
        ],
      ),
    );
  }
}

class _ScriptRow extends StatelessWidget {
  const _ScriptRow({required this.item});

  final PromptScript item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 44, right: 8),
      title: Text(item.name,
          style: const TextStyle(color: cream, fontSize: 13)),
      trailing: IconButton(
        tooltip: 'Copy ${item.name}',
        icon: const Icon(Icons.copy_rounded, color: gold, size: 18),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: item.body));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Copied "${item.name}"')));
        },
      ),
    );
  }
}
