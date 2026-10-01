import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Daily bars against a dashed goal line. Over-goal bars turn tomato.
class GoalBars extends StatelessWidget {
  const GoalBars({
    super.key,
    required this.values,
    required this.goal,
    required this.labels,
    this.height = 150,
    this.highlight,
  });

  final List<double> values;
  final double goal;
  final List<String> labels;
  final double height;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.slow,
            curve: Motion.curve,
            builder: (context, t, _) =>
                CustomPaint(painter: _BarsPainter(values, goal, t, highlight)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: T.caps.copyWith(fontSize: 10, letterSpacing: 0.4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.values, this.goal, this.t, this.highlight);

  final List<double> values;
  final double goal;
  final double t;
  final int? highlight;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = math.max(goal * 1.25, values.fold<double>(0, math.max));
    final slot = size.width / values.length;
    final w = math.min(slot * 0.56, 22.0);
    final bar = Paint();
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final x = slot * i + (slot - w) / 2;
      if (v <= 0) {
        bar.color = C.line;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - 3, w, 3),
            const Radius.circular(2),
          ),
          bar,
        );
        continue;
      }
      final h = size.height * (v / maxV) * t;
      bar.color = v > goal * 1.1
          ? C.tomato
          : (i == highlight ? C.ink : C.ink.withValues(alpha: 0.78));
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, size.height - h, w, h),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        bar,
      );
    }
    final y = size.height - size.height * goal / maxV;
    final dash = Paint()
      ..color = C.tomato
      ..strokeWidth = 1.2;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3.5, size.width), y), dash);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.t != t || old.values != values || old.goal != goal || old.highlight != highlight;
}

/// Weigh-ins as dots with a smoothed trend line through them.
class TrendLine extends StatelessWidget {
  const TrendLine({super.key, required this.points, required this.trend, this.height = 150});

  /// (x in 0..1, value)
  final List<(double, double)> points;
  final List<(double, double)> trend;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.slow,
      curve: Motion.curve,
      builder: (context, t, _) => CustomPaint(painter: _TrendPainter(points, trend, t)),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points, this.trend, this.t);

  final List<(double, double)> points;
  final List<(double, double)> trend;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final all = [...points.map((p) => p.$2), ...trend.map((p) => p.$2)];
    var lo = all.reduce(math.min);
    var hi = all.reduce(math.max);
    if (hi - lo < 1) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.5;
      hi = mid + 0.5;
    }
    final pad = (hi - lo) * 0.15;
    lo -= pad;
    hi += pad;
    const inset = 6.0;
    Offset at((double, double) p) => Offset(
      inset + p.$1 * (size.width - inset * 2),
      size.height - (p.$2 - lo) / (hi - lo) * size.height,
    );

    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, -8, size.width * t + 8, size.height + 16));
    final dot = Paint()..color = C.ink3;
    for (final p in points) {
      canvas.drawCircle(at(p), 2.6, dot);
    }
    if (trend.length > 1) {
      final path = Path()..moveTo(at(trend.first).dx, at(trend.first).dy);
      for (final p in trend.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = C.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(at(trend.last), 4.5, Paint()..color = C.tomato);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.t != t || old.points != points;
}
