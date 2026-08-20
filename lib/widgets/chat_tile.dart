import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models.dart';
import '../theme.dart';
import 'icon_avatar.dart';

/// Chat card per the design system: icon avatar with status dot, name,
/// agent/model chip + run state, time + unread badge, preview line, and a
/// pause/resume power toggle for non-main chats.
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

  String get _timeLabel {
    final ts = chat.lastTs;
    if (ts <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d.$mo';
  }

  @override
  Widget build(BuildContext context) {
    final running = status?.isRunning == true;
    final isMain = chat.isMain;
    final name = displayName ?? chat.name;
    final sessionActive = !paused;
    final statusText = paused
        ? 'Paused'
        : running
            ? 'Running'
            : 'Idle';
    final statusColor = paused ? red : running ? greenBright : outline;
    return Material(
      color: ink2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: paused
                    ? red.withValues(alpha: 0.5)
                    : running
                        ? gold.withValues(alpha: 0.6)
                        : borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconAvatar(
                    seed: '${chat.id}|${chat.name}',
                    size: 40,
                    statusActive: sessionActive,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: cream)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (running)
                              const Icon(Icons.bolt_rounded,
                                  size: 13, color: greenBright),
                            if (running) const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                isMain ? 'Hermes Admin' : 'Agent Session',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: monoFamily,
                                    fontSize: 11,
                                    color: sand)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                  color: outline, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(statusText,
                                  style: TextStyle(
                                      fontFamily: monoFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_timeLabel,
                          style: TextStyle(
                              fontFamily: monoFamily,
                              fontSize: 11,
                              color: outline)),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: gold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                                color: onPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paused
                          ? 'Session paused — agent is asleep'
                          : running
                              ? 'Agent is working on this session…'
                              : isMain
                                  ? 'WhatsApp sync · admin channel'
                                  : 'Separate agent session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: paused
                              ? red.withValues(alpha: 0.9)
                              : running
                                  ? greenBright.withValues(alpha: 0.85)
                                  : sand),
                    ),
                  ),
                  if (onToggle != null)
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: sessionActive,
                        onChanged: (_) => onToggle!(),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded,
                        color: outline, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
