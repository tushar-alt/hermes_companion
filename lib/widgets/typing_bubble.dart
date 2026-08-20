import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'cartoon_avatar.dart';

/// Google-style "thinking…" indicator: ONE gold shape that morphs in a fixed
/// position — circle → triangle → square → diamond and back — with a liquid
/// smoothed outline, a slowly rotating gradient, a breathing glow and an
/// echo ring expanding from the same center. The shape itself never moves.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key, this.seed = 'main'});

  /// Seed for the assistant's cartoon avatar (chat id).
  final String seed;

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 8),
            child: CartoonAvatar(seed: widget.seed, size: 28),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x2EC9A24B)),
              boxShadow: const [
                BoxShadow(color: Color(0x22C9A24B), blurRadius: 14),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CustomPaint(
                        painter: _MorphingShapePainter(t: t),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Opacity(
                      opacity: 0.7 + 0.3 * math.sin(t * 2 * math.pi * 2),
                      child: const Text('thinking…',
                          style: TextStyle(
                              color: gold,
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
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

/// Paints one shape that morphs through circle → triangle → square → diamond
/// by interpolating sampled boundary radii between the four keyframes. The
/// shape stays centered; only the gradient, glow and an expanding echo ring
/// animate.
class _MorphingShapePainter extends CustomPainter {
  _MorphingShapePainter({required this.t});

  final double t;

  static const int _n = 48; // boundary samples per shape
  static final List<List<double>> _shapes = _buildShapes();

  static List<List<double>> _buildShapes() {
    final circle = List<double>.filled(_n, 1.0);
    final triangle = _sampleBoundary(const [
      Offset(0, -1), // up
      Offset(0.866, 0.5),
      Offset(-0.866, 0.5),
    ]);
    final square = _sampleBoundary(const [
      Offset(0.707, -0.707),
      Offset(0.707, 0.707),
      Offset(-0.707, 0.707),
      Offset(-0.707, -0.707),
    ]);
    final diamond = _sampleBoundary(const [
      Offset(1, 0),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(0, -1),
    ]);
    return [circle, triangle, square, diamond];
  }

  /// Exact distance from the center to the polygon edge along each sample
  /// angle, so straight edges morph correctly instead of pinching.
  static List<double> _sampleBoundary(List<Offset> verts) {
    final out = <double>[];
    for (var i = 0; i < _n; i++) {
      final phi = 2 * math.pi * i / _n;
      final dir = Offset(math.cos(phi), math.sin(phi));
      var best = double.infinity;
      for (var e = 0; e < verts.length; e++) {
        final t = _raySegmentIntersect(Offset.zero, dir, verts[e],
            verts[(e + 1) % verts.length]);
        if (t != null && t > 0 && t < best) best = t;
      }
      out.add(best == double.infinity ? 1.0 : best);
    }
    return out;
  }

  static double? _raySegmentIntersect(
      Offset o, Offset dir, Offset a, Offset b) {
    final v1 = o - a;
    final v2 = b - a;
    final v3 = Offset(-dir.dy, dir.dx);
    final denom = v2.dx * v3.dx + v2.dy * v3.dy;
    if (denom.abs() < 1e-9) return null; // parallel
    final t1 = (v1.dx * v3.dx + v1.dy * v3.dy) / denom;
    final t2 = (v1.dx * dir.dy - v1.dy * dir.dx) / denom;
    if (t2 < 0 || t2 > 1) return null; // outside the segment
    return t1;
  }

  /// Where in the 4-segment cycle are we → current boundary radii.
  List<double> _radiiAt(double t) {
    final x = (t * 4).clamp(0.0, 3.999);
    final seg = x.floor();
    var f = x - seg;
    f = f * f * (3 - 2 * f); // smoothstep
    final a = _shapes[seg];
    final b = _shapes[(seg + 1) % _shapes.length];
    return [
      for (var i = 0; i < _n; i++) a[i] + (b[i] - a[i]) * f,
    ];
  }

  /// Soft "liquid" outline: quadratic curves through the edge midpoints.
  Path _blobPath(Offset c, double rr, List<double> radii) {
    final pts = <Offset>[
      for (var i = 0; i < _n; i++)
        Offset(
          c.dx + math.cos(2 * math.pi * i / _n) * radii[i] * rr,
          c.dy + math.sin(2 * math.pi * i / _n) * radii[i] * rr,
        ),
    ];
    final path = Path();
    final start = (pts.last + pts.first) / 2;
    path.moveTo(start.dx, start.dy);
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final mid = (p + pts[(i + 1) % pts.length]) / 2;
      path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final radii = _radiiAt(t);
    final blob = _blobPath(center, r, radii);

    // 1) Echo ring: the same silhouette expands from the same center and
    //    fades — once per cycle. The shape itself never moves.
    final cyc = t;
    final echoScale = 1.0 + 1.15 * cyc;
    final echoOpacity = (1 - cyc) * 0.30;
    if (echoOpacity > 0.01) {
      canvas.drawPath(
        _blobPath(center, r * echoScale, radii),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = gold.withValues(alpha: echoOpacity),
      );
    }

    // 2) Breathing glow behind the blob.
    final glow = 0.30 + 0.15 * math.sin(t * 2 * math.pi * 2);
    canvas.drawPath(
      blob,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..color = gold.withValues(alpha: glow),
    );

    // 3) The blob itself: gradient slowly rotating in place (geometry stays
    //    put — only the light moves across the surface).
    final angle = t * 2 * math.pi * 0.5;
    final grad = LinearGradient(
      begin: const Alignment(0, -1),
      end: const Alignment(0, 1),
      colors: const [goldHi, gold, goldLo],
      transform: GradientRotation(angle),
    );
    canvas.drawPath(
      blob,
      Paint()..shader = grad.createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_MorphingShapePainter oldDelegate) => oldDelegate.t != t;
}
