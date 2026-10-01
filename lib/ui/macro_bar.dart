import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class MacroValue {
  const MacroValue(this.label, this.eaten, this.target, this.color);

  final String label;
  final double eaten;
  final double target;
  final Color color;
}

/// Split bar showing what today's plate is made of, with eaten/target legend.
class MacroSplit extends StatelessWidget {
  const MacroSplit({super.key, required this.values});

  final List<MacroValue> values;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (s, v) => s + v.eaten);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 8,
        child: LayoutBuilder(builder: (context, box) {
          final gap = 3.0 * (values.length - 1);
          final avail = box.maxWidth - gap;
          return Row(children: [
            for (var i = 0; i < values.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              AnimatedContainer(
                duration: Motion.slow,
                curve: Motion.curve,
                width: total <= 0 ? avail / values.length : avail * values[i].eaten / total,
                decoration: BoxDecoration(
                  color: total <= 0 ? C.line : values[i].color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ]);
        }),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final v in values)
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '● ', style: TextStyle(color: v.color, fontSize: 10)),
              TextSpan(text: '${v.label} '),
              TextSpan(
                  text: v.eaten.round().toString(),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              TextSpan(text: '/${v.target.round()}g', style: const TextStyle(color: C.ink2)),
            ]),
            style: T.small.copyWith(color: C.ink),
          ),
      ]),
    ]);
  }
}

/// Thin labelled progress bar, used for single macros.
class MacroLine extends StatelessWidget {
  const MacroLine({super.key, required this.value});

  final MacroValue value;

  @override
  Widget build(BuildContext context) {
    final t = value.target <= 0 ? 0.0 : (value.eaten / value.target).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value.label.toUpperCase(), style: T.caps),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: [
        TextSpan(text: value.eaten.round().toString(), style: T.heading),
        TextSpan(text: ' /${value.target.round()}g', style: T.small),
      ])),
      const SizedBox(height: 8),
      Container(
        height: 3,
        color: C.line,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: t,
          child: Container(color: value.color),
        ),
      ),
    ]);
  }
}
