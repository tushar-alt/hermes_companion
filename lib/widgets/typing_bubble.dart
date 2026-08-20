import 'package:flutter/material.dart';

import '../theme.dart';
import 'icon_avatar.dart';

/// Design-system "thinking" indicator: agent avatar with a pulsing dot, three
/// bouncing dots and a softly pulsing "Hermes is thinking…" label.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key, this.seed = 'main'});

  /// Seed for the assistant's avatar (chat id).
  final String seed;

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconAvatar(seed: widget.seed, size: 28, icon: Icons.smart_toy_rounded),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Opacity(
                        opacity: 0.35 + 0.65 * ((t + i * 0.2) % 1.0).abs().clamp(0.0, 1.0) >= 0.5
                            ? 1.0 - ((t + i * 0.2) % 1.0)
                            : (t + i * 0.2) % 1.0,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: greenBright,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Opacity(
                      opacity: 0.75 + 0.25 * ((t * 2) % 1.0),
                      child: const Text('Hermes is thinking…',
                          style: TextStyle(
                              fontFamily: monoFamily,
                              color: greenBright,
                              fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
