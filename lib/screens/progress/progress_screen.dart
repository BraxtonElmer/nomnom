import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/activity.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/charts.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/macro_bar.dart';
import 'week_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _weightDays = 30;
  int _kcalDays = 7;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, Activity.i]),
      builder: (context, _) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(S.gutter, 12, S.gutter, 32),
          children: [
            Text('Progress', style: T.title),
            const SizedBox(height: 22),
            const WeekCard(),
            const SizedBox(height: 30),
            _weight(),
            const SizedBox(height: 34),
            _calories(),
            if (Activity.i.connected) ...[const SizedBox(height: 34), _activity()],
            const SizedBox(height: 34),
            _macros(),
          ],
        ),
      ),
    );
  }

  // Weight

  Widget _weight() {
    final s = Store.i;
    final metric = s.profile.metric;
    final today = dayOf(DateTime.now());
    final from = _weightDays == 0 ? null : today.subtract(Duration(days: _weightDays));
    final list = s.weights.where((w) => from == null || !w.day.isBefore(from)).toList();
    final trend = emaTrend(s.weights);
    final shownTrend = trend.where((w) => from == null || !w.day.isBefore(from)).toList();

    final start = (from ?? (list.isEmpty ? today : list.first.day));
    final span = today.difference(start).inDays.clamp(1, 100000).toDouble();
    double x(DateTime d) => (d.difference(start).inDays / span).clamp(0.0, 1.0);

    final latest = trend.isEmpty ? null : trend.last.kg;
    final change = shownTrend.length < 2 ? null : shownTrend.last.kg - shownTrend.first.kg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('WEIGHT', style: T.caps)),
            TextLink(label: '+ Log weight', onTap: _logWeight),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              latest == null ? '—' : kg(latest, metric),
              style: T.display.copyWith(fontSize: 40),
            ),
            const SizedBox(width: 12),
            if (change != null) ...[
              Icon(
                change <= 0 ? Icons.south_rounded : Icons.north_rounded,
                size: 14,
                color: _goodDirection(change) ? C.good : C.tomato,
              ),
              Text(
                ' ${kg(change.abs(), metric)} ${_weightDays == 0 ? 'overall' : 'in $_weightDays days'}',
                style: T.small.copyWith(
                  color: _goodDirection(change) ? C.good : C.tomato,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        Text(
          latest == null ? 'Smoothed trend' : '${bmiLabel(s.profile, latest)} · smoothed trend',
          style: T.small,
        ),
        const SizedBox(height: 16),
        if (list.length < 2)
          Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: C.line),
              borderRadius: BorderRadius.circular(S.radius),
            ),
            child: Text('Log your weight a couple of times to see a trend.', style: T.small),
          )
        else
          TrendLine(
            points: [for (final w in list) (x(w.day), metric ? w.kg : w.kg * 2.20462)],
            trend: [for (final w in shownTrend) (x(w.day), metric ? w.kg : w.kg * 2.20462)],
          ),
        const SizedBox(height: 14),
        Segmented<int>(
          values: const [30, 90, 0],
          labels: const ['30 days', '90 days', 'All'],
          value: _weightDays,
          onChanged: (v) => setState(() => _weightDays = v),
        ),
      ],
    );
  }

  bool _goodDirection(double change) => switch (Store.i.profile.goal) {
    Goal.lose => change <= 0,
    Goal.gain => change >= 0,
    Goal.maintain => change.abs() < 1,
  };

  Future<void> _logWeight() async {
    final metric = Store.i.profile.metric;
    final current = Store.i.profile.weightKg * (metric ? 1 : 2.20462);
    final c = TextEditingController(text: formatNum((current * 10).round() / 10));
    final v = await showPaperSheet<double>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Today’s weight', style: T.heading),
            const SizedBox(height: 18),
            PaperField(
              label: 'Weight',
              controller: c,
              autofocus: true,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              suffix: metric ? 'kg' : 'lb',
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save',
              onTap: () {
                final n = double.tryParse(c.text.replaceAll(',', '.'));
                if (n != null && n > 20 && n < 700) {
                  Navigator.pop(context, metric ? n : n / 2.20462);
                }
              },
            ),
          ],
        ),
      ),
    );
    if (v != null) await Store.i.logWeight(DateTime.now(), v);
  }

  // Calories

  Widget _calories() {
    final s = Store.i;
    final goal = s.targets.kcal;
    final today = dayOf(DateTime.now());
    final days = [for (var i = _kcalDays - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final values = [for (final d in days) s.totalOn(d).kcal];
    final logged = values.where((v) => v > 0).toList();
    final avg = logged.isEmpty ? 0.0 : logged.reduce((a, b) => a + b) / logged.length;
    final labels = _kcalDays == 7
        ? [for (final d in days) DateFormat.E().format(d).substring(0, 1)]
        : [for (var i = 0; i < days.length; i++) i % 5 == 0 ? '${days[i].day}' : ''];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('CALORIES', style: T.caps),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(logged.isEmpty ? '—' : kcal(avg), style: T.display.copyWith(fontSize: 40)),
            const SizedBox(width: 10),
            Text('avg a day · goal ${kcal(goal)}', style: T.small),
          ],
        ),
        const SizedBox(height: 18),
        GoalBars(values: values, goal: goal, labels: labels, highlight: values.length - 1),
        const SizedBox(height: 14),
        Segmented<int>(
          values: const [7, 30],
          labels: const ['7 days', '30 days'],
          value: _kcalDays,
          onChanged: (v) => setState(() => _kcalDays = v),
        ),
      ],
    );
  }

  // Activity, from Health Connect

  Widget _activity() {
    final today = dayOf(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final steps = [for (final d in days) Activity.i.on(d).steps.toDouble()];
    final withSteps = steps.where((v) => v > 0).toList();
    final avg = withSteps.isEmpty ? 0.0 : withSteps.reduce((a, b) => a + b) / withSteps.length;
    final sleep = Activity.i.sleepMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ACTIVITY', style: T.caps),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(withSteps.isEmpty ? '—' : kcal(avg), style: T.display.copyWith(fontSize: 40)),
            const SizedBox(width: 10),
            Text('steps a day · goal 8,000', style: T.small),
          ],
        ),
        const SizedBox(height: 18),
        GoalBars(
          values: steps,
          goal: 8000,
          labels: [for (final d in days) DateFormat.E().format(d).substring(0, 1)],
          highlight: 6,
          overIsBad: false,
        ),
        const SizedBox(height: 10),
        RuledRow(
          label: 'Active calories today',
          value: '${kcal(Activity.i.on(today).activeKcal)} kcal',
        ),
        RuledRow(
          label: 'Sleep last night',
          value: sleep == null ? 'No data' : '${sleep ~/ 60}h ${sleep % 60}m',
          last: true,
        ),
      ],
    );
  }

  // Macros

  Widget _macros() {
    final s = Store.i;
    final t = s.targets;
    final today = dayOf(DateTime.now());
    var n = 0;
    var sum = Nutrients.zero;
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      if (s.hasLog(d)) {
        n++;
        sum = sum + s.totalOn(d);
      }
    }
    final avg = n == 0 ? Nutrients.zero : sum.scale(1 / n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MACROS · 7-DAY AVERAGE', style: T.caps),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MacroLine(value: MacroValue('Protein', avg.protein, t.protein, C.protein)),
            ),
            const SizedBox(width: 18),
            Expanded(child: MacroLine(value: MacroValue('Carbs', avg.carbs, t.carbs, C.carbs))),
            const SizedBox(width: 18),
            Expanded(child: MacroLine(value: MacroValue('Fat', avg.fat, t.fat, C.fat))),
          ],
        ),
        const SizedBox(height: 26),
        Container(height: 1, color: C.line),
        RuledRow(label: 'Current streak', value: '${s.streak} days'),
        RuledRow(label: 'Days logged', value: '${s.loggedDays.length}', last: true),
      ],
    );
  }
}

/// Exponential moving average over weigh-ins, one point per weigh-in.
List<WeightEntry> emaTrend(List<WeightEntry> ws, {double alpha = 0.3}) {
  final out = <WeightEntry>[];
  double? t;
  for (final w in ws) {
    t = t == null ? w.kg : t + alpha * (w.kg - t);
    out.add(WeightEntry(day: w.day, kg: t));
  }
  return out;
}
