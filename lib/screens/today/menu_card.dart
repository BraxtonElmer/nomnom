import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/tokens.dart';
import '../../ui/format.dart';
import '../../ui/pressable.dart';

/// The day printed like a restaurant menu: meal headings, dotted leaders,
/// a ruled total.
class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.title,
    required this.entries,
    required this.goal,
    required this.onTap,
    this.isToday = true,
    this.pending = const [],
    this.onTapPending,
    this.yesterday = const [],
    this.onRepeat,
  });

  final String title;
  final List<Entry> entries;
  final double goal;
  final ValueChanged<Entry> onTap;
  final bool isToday;

  /// Logs saved while offline, shown under their meal until they're read.
  final List<PendingLog> pending;
  final ValueChanged<PendingLog>? onTapPending;

  /// Yesterday's entries, offered as "same as yesterday" for empty meals.
  final List<Entry> yesterday;
  final ValueChanged<List<Entry>>? onRepeat;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<double>(0, (s, e) => s + e.total.kcal);
    final left = goal - total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: C.lineStrong, offset: Offset(0, 1)),
          BoxShadow(color: C.shadow, blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(title, style: T.heading.copyWith(fontSize: 28))),
              Text('KCAL', style: T.caps),
            ],
          ),
          const SizedBox(height: 6),
          for (final meal in Meal.values) _section(meal),
          const SizedBox(height: 14),
          Container(height: 1, color: C.ink),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Total ', style: T.body),
              Text('of ${kcal(goal)}', style: T.small),
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(end: total),
                duration: Motion.slow,
                curve: Motion.curve,
                builder: (context, v, _) => Text(kcal(v), style: T.heading.copyWith(fontSize: 28)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(left >= 0 ? 'Remaining' : 'Over', style: T.small),
              const Spacer(),
              Text(
                kcal(left.abs()),
                style: T.small.copyWith(
                  color: left >= 0 ? C.tomato : C.tomato,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(Meal meal) {
    final list = entries.where((e) => e.meal == meal).toList();
    final waiting = pending.where((p) => p.meal == meal).toList();
    final heading = list.isEmpty ? meal.label : '${meal.label} · ${time(list.first.at)}';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading.toUpperCase(),
            style: T.caps.copyWith(
              color: list.isEmpty && waiting.isEmpty ? C.ink3 : C.tomato,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          for (final e in list) _line(e),
          for (final p in waiting) _waiting(p),
          if (list.isEmpty && waiting.isEmpty)
            Row(
              children: [
                Text(
                  isToday ? 'Not yet' : '—',
                  style: TextStyle(
                    fontFamily: F.serif,
                    fontStyle: FontStyle.italic,
                    fontSize: 18,
                    color: C.ink3,
                  ),
                ),
                const Spacer(),
                if (isToday && onRepeat != null) ..._repeat(meal),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> _repeat(Meal meal) {
    final same = yesterday.where((e) => e.meal == meal).toList();
    if (same.isEmpty) return const [];
    final k = same.fold<double>(0, (s, e) => s + e.total.kcal);
    return [
      Pressable(
        onTap: () => onRepeat!(same),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'Same as yesterday · ${kcal(k)}',
            style: T.small.copyWith(color: C.tomato, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    ];
  }

  Widget _waiting(PendingLog p) => Pressable(
    onTap: onTapPending == null ? null : () => onTapPending!(p),
    scale: 0.985,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '“${p.text}”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: F.serif,
                fontStyle: FontStyle.italic,
                fontSize: 18,
                color: C.ink2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('waiting', style: T.small.copyWith(color: C.carbs)),
        ],
      ),
    ),
  );

  Widget _line(Entry e) => Pressable(
    onTap: () => onTap(e),
    scale: 0.985,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.76),
              child: Text(e.title, style: T.body, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const Expanded(child: _Leader()),
            Text(kcal(e.total.kcal), style: T.bodyStrong),
          ],
        ),
      ),
    ),
  );
}

/// Dotted leader line between a dish and its price, er, calories.
class _Leader extends StatelessWidget {
  const _Leader();

  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    constraints: const BoxConstraints(minWidth: 16),
    margin: const EdgeInsets.fromLTRB(8, 0, 8, 5),
    child: CustomPaint(painter: _DotsPainter()),
  );
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = C.lineStrong;
    for (var x = 1.5; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, size.height - 1.5), 1, p);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => false;
}
