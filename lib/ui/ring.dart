import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fine-line progress ring. Animates between values; overflow past the goal
/// draws a second lap in tomato so going over is visible but not alarming.
class CalorieRing extends StatelessWidget {
  const CalorieRing({
    super.key,
    required this.value,
    required this.goal,
    this.size = 148,
    this.stroke = 6,
    required this.child,
  });

  final double value;
  final double goal;
  final double size;
  final double stroke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = goal <= 0 ? 0.0 : value / goal;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (context, t, _) => CustomPaint(
          painter: _RingPainter(t, stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.stroke);

  final double t;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = C.line;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (t <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = C.ink;
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * t.clamp(0, 1), false, arc);
    if (t > 1) {
      arc.color = C.tomato;
      canvas.drawArc(r, -math.pi / 2, math.pi * 2 * (t - 1).clamp(0, 1), false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.stroke != stroke;
}
