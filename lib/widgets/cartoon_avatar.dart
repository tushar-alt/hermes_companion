import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A deterministic cartoon face avatar (male/female, varied skin, hair, eyes,
/// occasionally glasses) generated from a seed string, so every chat gets its
/// own stable avatar with no network calls and no asset files.
class CartoonAvatar extends StatelessWidget {
  const CartoonAvatar({super.key, required this.seed, this.size = 46});

  final String seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _FacePainter.backgroundFor(seed),
        border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.2),
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size.square(size),
          painter: _FacePainter(seed: seed),
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter({required this.seed});

  final String seed;

  // ── deterministic PRNG (FNV-1a + xorshift) ───────────────────────────
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  static int _next(int seed) {
    var x = seed;
    x = ((x ^ (x >> 15)) * 0x2c1b3c6d) & 0xFFFFFFFF;
    x = ((x ^ (x >> 12)) * 0x297a2d39) & 0xFFFFFFFF;
    x = (x ^ (x >> 15)) & 0xFFFFFFFF;
    return x;
  }

  static T _pick<T>(List<T> list, int hash, [int salt = 0]) {
    var h = hash;
    for (var i = 0; i <= salt; i++) {
      h = _next(h);
    }
    return list[h % list.length];
  }

  static Gradient backgroundFor(String seed) {
    final h = _hash(seed);
    const bgs = <List<Color>>[
      [Color(0xFF5B3A29), Color(0xFF2A1B12)], // warm brown
      [Color(0xFF1F3A5F), Color(0xFF101F33)], // deep blue
      [Color(0xFF3A5F2A), Color(0xFF1B2A12)], // forest
      [Color(0xFF5F2A4E), Color(0xFF2A1221)], // plum
      [Color(0xFF4A3A6F), Color(0xFF221A33)], // violet
      [Color(0xFF8A6A2A), Color(0xFF3A2A10)], // amber
    ];
    final c = bgs[h % bgs.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: c,
    );
  }

  static const _skins = <Color>[
    Color(0xFFF8DCC2),
    Color(0xFFF2C9A0),
    Color(0xFFE8B88A),
    Color(0xFFC68642),
    Color(0xFF8D5524),
  ];
  static const _hairs = <Color>[
    Color(0xFF2B1B0E), // near-black
    Color(0xFF4A2F1B), // dark brown
    Color(0xFF8A5A2B), // brown
    Color(0xFFC9A24B), // blonde
    Color(0xFFB33A3A), // red
    Color(0xFF3A3A3A), // grey
    Color(0xFF6B4F2A), // chestnut
  ];
  static const _eyes = <Color>[
    Color(0xFF3A2A1A), // brown
    Color(0xFF2A4A8A), // blue
    Color(0xFF2A6A3A), // green
    Color(0xFF4A3A6A), // hazel
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final h = _hash(seed);
    final female = (h & 1) == 0;
    final skin = _pick(_skins, h, 1);
    final hair = _pick(_hairs, h, 2);
    final eye = _pick(_eyes, h, 3);
    final glasses = _pick(const [false, false, false, true], h, 4);
    final shadow = Color.lerp(skin, Colors.black, 0.25)!;

    Offset c(double x, double y) => Offset(x * s, y * s);

    // Long hair behind the head (female).
    if (female) {
      canvas.drawCircle(c(0.5, 0.46), 0.34 * s, Paint()..color = hair);
      canvas.drawCircle(c(0.17, 0.60), 0.11 * s, Paint()..color = hair);
      canvas.drawCircle(c(0.83, 0.60), 0.11 * s, Paint()..color = hair);
    }

    // Head.
    canvas.drawCircle(c(0.5, 0.52), 0.28 * s, Paint()..color = skin);

    // Ears.
    canvas.drawCircle(c(0.21, 0.55), 0.055 * s, Paint()..color = skin);

    // Hair on top: cap (male) or fringe (female).
    final hairPath = Path()
      ..addArc(
        Rect.fromCircle(
            center: female ? c(0.5, 0.49) : c(0.5, 0.52),
            radius: (female ? 0.27 : 0.285) * s),
        math.pi,
        math.pi,
      )
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);

    // Eyebrows.
    final brow = Paint()
      ..color = hair
      ..strokeWidth = 0.02 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c(0.37, 0.43), c(0.44, 0.44), brow);
    canvas.drawLine(c(0.56, 0.44), c(0.63, 0.43), brow);

    // Eyes.
    for (final ex in const [0.40, 0.60]) {
      final ec = c(ex, 0.52);
      canvas.drawCircle(ec, 0.075 * s, Paint()..color = Colors.white);
      canvas.drawCircle(ec, 0.040 * s, Paint()..color = eye);
      canvas.drawCircle(
        ec.translate(0.014 * s, -0.014 * s),
        0.013 * s,
        Paint()..color = Colors.white,
      );
    }

    // Nose (tiny soft curve).
    final nose = Path()
      ..moveTo(c(0.5, 0.57).dx, c(0.5, 0.57).dy)
      ..quadraticBezierTo(
          c(0.545, 0.60).dx, c(0.545, 0.60).dy, c(0.5, 0.63).dx, c(0.5, 0.63).dy);
    canvas.drawPath(
      nose,
      Paint()
        ..color = shadow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012 * s
        ..strokeCap = StrokeCap.round,
    );

    // Smile.
    final mouth = Path()
      ..moveTo(c(0.43, 0.66).dx, c(0.43, 0.66).dy)
      ..quadraticBezierTo(
          c(0.5, 0.71).dx, c(0.5, 0.71).dy, c(0.57, 0.66).dx, c(0.57, 0.66).dy);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF8A3A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.016 * s
        ..strokeCap = StrokeCap.round,
    );

    // Blush.
    final blush = Paint()..color = const Color(0xFFE88A8A).withValues(alpha: 0.5);
    canvas.drawCircle(c(0.36, 0.62), 0.03 * s, blush);
    canvas.drawCircle(c(0.64, 0.62), 0.03 * s, blush);

    // Glasses (some avatars).
    if (glasses) {
      final gp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.014 * s
        ..color = const Color(0xFF2A2A2A);
      canvas.drawCircle(c(0.40, 0.52), 0.085 * s, gp);
      canvas.drawCircle(c(0.60, 0.52), 0.085 * s, gp);
      canvas.drawLine(c(0.485, 0.52), c(0.515, 0.52), gp);
      canvas.drawLine(c(0.315, 0.52), c(0.29, 0.50), gp);
      canvas.drawLine(c(0.685, 0.52), c(0.71, 0.50), gp);
    }
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) => oldDelegate.seed != seed;
}
