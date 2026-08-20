import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models.dart';
import '../theme.dart';
import 'cartoon_avatar.dart';
import 'status_dot.dart';

class ChatTile extends StatelessWidget {
  const ChatTile({
    super.key,
    required this.chat,
    required this.connected,
    required this.onTap,
    this.onLongPress,
    this.status,
    this.unread = 0,
    this.displayName,
    this.paused = false,
    this.onToggle,
  });

  final ChatInfo chat;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ChatStatus? status;
  final int unread;

  /// Overrides the displayed name (e.g. "Hermes Admin" for the main chat).
  final String? displayName;

  /// True when this chat's agent session is paused (sleeping).
  final bool paused;

  /// When non-null a session power toggle is shown on the tile.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final running = status?.isRunning == true;
    final isMain = chat.isMain;
    final name = displayName ?? chat.name;
    final sessionActive = !paused;
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: paused
                    ? const Color(0x55B33A3A)
                    : Color(running ? 0x55C9A24B : 0x1AF5EFE3)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CartoonAvatar(seed: '${chat.id}|${chat.name}', size: 46),
                  if (onToggle != null)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: surface,
                          shape: BoxShape.circle,
                        ),
                        child: StatusDot(active: sessionActive, size: 9),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fraunces(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: cream)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (running) ...[
                          const Icon(Icons.bolt_rounded, size: 13, color: gold),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          paused
                              ? 'paused — sleeping'
                              : running
                                  ? 'working…'
                                  : isMain
                                      ? 'WhatsApp sync'
                                      : 'separate session',
                          style: TextStyle(
                              fontSize: 12,
                              color: paused
                                  ? red
                                  : running
                                      ? gold
                                      : sand),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isMain)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('LIVE',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: green)),
                ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                        color: bg,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              if (onToggle != null)
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: sessionActive,
                    onChanged: (_) => onToggle!(),
                    activeThumbColor: green,
                    activeTrackColor: green.withValues(alpha: 0.4),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: sand, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
