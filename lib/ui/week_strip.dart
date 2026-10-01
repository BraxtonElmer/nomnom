import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

/// Monday-first week capsule. Swipe sideways for other weeks.
class WeekStrip extends StatefulWidget {
  const WeekStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.hasLog,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime day) hasLog;

  @override
  State<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<WeekStrip> {
  static const _origin = 1000;
  late final PageController _pages = PageController(initialPage: _pageFor(widget.selected));

  DateTime get _thisMonday {
    final t = dayOf(DateTime.now());
    return t.subtract(Duration(days: t.weekday - 1));
  }

  int _pageFor(DateTime d) {
    final monday = dayOf(d).subtract(Duration(days: d.weekday - 1));
    return _origin + (monday.difference(_thisMonday).inDays / 7).round();
  }

  @override
  void didUpdateWidget(WeekStrip old) {
    super.didUpdateWidget(old);
    final page = _pageFor(widget.selected);
    if (_pages.hasClients && _pages.page?.round() != page) {
      _pages.animateToPage(page, duration: Motion.base, curve: Motion.curve);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: C.paperDeep, borderRadius: BorderRadius.circular(22)),
      child: PageView.builder(
        controller: _pages,
        itemCount: _origin + 1, // no weeks in the future
        itemBuilder: (context, page) {
          final monday = _thisMonday.add(Duration(days: 7 * (page - _origin)));
          return Row(
            children: List.generate(7, (i) {
              final day = monday.add(Duration(days: i));
              return Expanded(child: _day(day));
            }),
          );
        },
      ),
    );
  }

  Widget _day(DateTime day) {
    final today = dayOf(DateTime.now());
    final selected = day == dayOf(widget.selected);
    final future = day.isAfter(today);
    final logged = !future && widget.hasLog(day);
    final letter = DateFormat.E().format(day).substring(0, 1);
    return Pressable(
      onTap: future ? null : () => widget.onSelect(day),
      scale: 0.92,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected ? C.card : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? [BoxShadow(color: C.shadow, blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: T.caps.copyWith(
                letterSpacing: 0,
                color: selected ? C.tomato : (future ? C.ink3 : C.ink2),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: T.bodyStrong.copyWith(
                color: future ? C.ink3 : C.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              opacity: logged && !selected ? 1 : 0,
              duration: Motion.fast,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: C.tomato, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
