import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Small glowing status dot: green while a session is live, red when it is
/// paused/off. Pulses softly so "sleeping" is unmistakable at a glance.
class StatusDot extends StatefulWidget {
  const StatusDot({super.key, required this.active, this.size = 11});

  final bool active;
  final double size;

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? green : red;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.55 + 0.35 * pulse),
                blurRadius: 2 + 4 * pulse,
                spreadRadius: 0.5 + pulse,
              ),
            ],
          ),
        );
      },
    );
  }
}
