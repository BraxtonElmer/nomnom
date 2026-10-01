import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/format.dart';
import '../../ui/macro_bar.dart';
import '../../ui/pressable.dart';
import '../log/review_screen.dart';
import '../shell.dart';
import '../today/menu_card.dart';
import '../today/today_screen.dart';

/// How a day went against the goal.
enum DayMark { none, under, onTarget, over }

DayMark markFor(double eaten, double goal) {
  if (eaten <= 0) return DayMark.none;
  final r = eaten / goal;
  if (r > 1.1) return DayMark.over;
  if (r >= 0.9) return DayMark.onTarget;
  return DayMark.under;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected;

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int d) => setState(() {
    _month = DateTime(_month.year, _month.month + d);
    _selected = null;
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final goal = s.targets.kcal;
        final days = DateUtils.getDaysInMonth(_month.year, _month.month);
        final lead = DateTime(_month.year, _month.month).weekday - 1;
        final today = dayOf(DateTime.now());

        var logged = 0, onTarget = 0;
        var sum = 0.0;
        for (var d = 1; d <= days; d++) {
          final k = s.totalOn(DateTime(_month.year, _month.month, d)).kcal;
          if (k > 0) {
            logged++;
            sum += k;
            if (markFor(k, goal) == DayMark.onTarget) onTarget++;
          }
        }

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(S.gutter, 12, S.gutter, 32),
            children: [
              Row(
                children: [
                  const Expanded(child: Text('History', style: T.title)),
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    label: 'Previous month',
                    onTap: () => _shift(-1),
                  ),
                  CircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    label: 'Next month',
                    onTap: _isCurrentMonth ? null : () => _shift(1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  DateFormat.yMMMM().format(_month).toUpperCase(),
                  key: ValueKey(_month),
                  style: T.caps,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  for (final l in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(
                      child: Center(child: Text(l, style: T.caps)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox(),
                  for (var d = 1; d <= days; d++)
                    _cell(DateTime(_month.year, _month.month, d), goal, today),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const _Key(C.ink, 'On target'),
                  const SizedBox(width: 16),
                  const _Key(C.lineStrong, 'Under'),
                  const SizedBox(width: 16),
                  const _Key(C.tomato, 'Over'),
                ],
              ),
              const SizedBox(height: 22),
              Container(height: 1, color: C.ink),
              Row(
                children: [
                  _Fig('$logged', 'days logged'),
                  _Fig(logged == 0 ? '—' : kcal(sum / logged), 'avg kcal'),
                  _Fig('$onTarget', 'on target', last: true),
                ],
              ),
              Container(height: 1, color: C.line),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: Motion.base,
                child: _selected == null
                    ? Text(
                        'Tap a day to see what you ate.',
                        key: const ValueKey('hint'),
                        style: T.small,
                      )
                    : Column(
                        key: ValueKey(_selected),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MenuCard(
                            title: DateFormat('EEEE, d MMM').format(_selected!),
                            entries: s.entriesOn(_selected!),
                            goal: goal,
                            isToday: _selected == today,
                            onTap: (e) => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => ReviewScreen.edit(entry: e))),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextLink(
                              label: 'Log food for this day',
                              onTap: () {
                                TodayScreen.day.value = _selected!;
                                Shell.tab.value = 0;
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(DateTime day, double goal, DateTime today) {
    final future = day.isAfter(today);
    final mark = future ? DayMark.none : markFor(Store.i.totalOn(day).kcal, goal);
    final selected = day == _selected;
    final (bg, fg) = switch (mark) {
      DayMark.onTarget => (C.ink, C.paper),
      DayMark.over => (C.tomato, Colors.white),
      DayMark.under => (C.paperDeep, C.ink),
      DayMark.none => (Colors.transparent, future ? C.ink3 : C.ink2),
    };
    return Pressable(
      onTap: future ? null : () => setState(() => _selected = selected ? null : day),
      scale: 0.9,
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? C.tomato : (day == today ? C.ink : Colors.transparent),
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: T.body.copyWith(
            color: fg,
            fontWeight: mark == DayMark.none ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Dot(color, size: 9),
      Text(label, style: T.small),
    ],
  );
}

class _Fig extends StatelessWidget {
  const _Fig(this.value, this.label, {this.last = false});

  final String value;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(right: BorderSide(color: C.line)),
      ),
      child: Column(
        children: [
          Text(value, style: T.heading),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: T.caps.copyWith(fontSize: 10)),
        ],
      ),
    ),
  );
}
