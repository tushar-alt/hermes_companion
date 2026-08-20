import 'package:flutter/material.dart';

import '../theme.dart';
import 'status_dot.dart';

/// Deterministic avatar per the design system: a rounded circle with a
/// material icon chosen from the seed (terminal, analytics, image, …) and an
/// optional live-status dot overlay.
const List<IconData> _avatarIcons = [
  Icons.terminal_rounded,
  Icons.analytics_rounded,
  Icons.image_rounded,
  Icons.code_rounded,
  Icons.folder_shared_rounded,
  Icons.science_rounded,
  Icons.rocket_launch_rounded,
  Icons.bolt_rounded,
  Icons.dataset_rounded,
  Icons.insights_rounded,
];

IconData avatarIconFor(String seed) {
  var h = 0x811c9dc5;
  for (final c in seed.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return _avatarIcons[h % _avatarIcons.length];
}

class IconAvatar extends StatelessWidget {
  const IconAvatar({
    super.key,
    required this.seed,
    this.size = 40,
    this.icon,
    this.statusActive,
    this.statusDotSize = 10,
  });

  final String seed;
  final double size;

  /// Optional explicit icon (defaults to a deterministic one from [seed]).
  final IconData? icon;

  /// When non-null a live-status dot is drawn at the bottom-right.
  final bool? statusActive;
  final double statusDotSize;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: surfaceHigh,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon ?? avatarIconFor(seed),
          size: size * 0.5,
          color: goldHi),
    );
    if (statusActive == null) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -size * 0.04,
          bottom: -size * 0.04,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: StatusDot(
                active: statusActive!, size: statusDotSize),
          ),
        ),
      ],
    );
  }
}
