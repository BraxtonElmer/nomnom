import 'dart:convert';

import '../ai/client.dart';
import '../data/models.dart';
import 'targets.dart';

/// Monday of the week [d] falls in.
DateTime weekStart(DateTime d) =>
    addDays(d, 1 - d.weekday);

/// The numbers behind a weekly recap. Everything the recap says comes from
/// here; the AI only gets to word it.
class WeekStats {
  const WeekStats({
    required this.start,
    required this.logged,
    required this.avg,
    required this.targets,
    required this.onTarget,
    required this.proteinDays,
    required this.weightChange,
    required this.top,
  });

  /// Monday.
  final DateTime start;
  final int logged;

  /// Average over the logged days.
  final Nutrients avg;
  final Targets targets;

  /// Logged days within 10% of the kcal goal.
  final int onTarget;

  /// Logged days that reached the protein target.
  final int proteinDays;

  /// Mean weigh-in this week minus the week before, when both have one.
  final double? weightChange;

  /// Most logged foods, most frequent first.
  final List<String> top;

  static const minDays = 3;

  /// Stats for the week starting [start], or null with fewer than [minDays]
  /// logged days.
  static WeekStats? compute({
    required DateTime start,
    required List<Entry> Function(DateTime day) entriesOn,
    required Targets targets,
    required List<WeightEntry> weights,
  }) {
    var logged = 0;
    var onTarget = 0;
    var proteinDays = 0;
    var sum = Nutrients.zero;
    final counts = <String, int>{};
    for (var i = 0; i < 7; i++) {
      final entries = entriesOn(addDays(start, i));
      if (entries.isEmpty) continue;
      final total = entries.fold(Nutrients.zero, (s, e) => s + e.total);
      logged++;
      sum = sum + total;
      if ((total.kcal - targets.kcal).abs() <= targets.kcal * 0.1) onTarget++;
      if (total.protein >= targets.protein * 0.95) proteinDays++;
      for (final e in entries) {
        for (final item in e.items) {
          final k = item.name.toLowerCase().trim();
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
    }
    if (logged < minDays) return null;

    double? mean(DateTime from) {
      final to = addDays(from, 7);
      final ws = weights
          .where((w) => !w.day.isBefore(from) && w.day.isBefore(to))
          .toList();
      return ws.isEmpty ? null : ws.fold(0.0, (s, w) => s + w.kg) / ws.length;
    }

    final now = mean(start);
    final before = mean(addDays(start, -7));
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return WeekStats(
      start: start,
      logged: logged,
      avg: sum.scale(1 / logged),
      targets: targets,
      onTarget: onTarget,
      proteinDays: proteinDays,
      weightChange: now == null || before == null ? null : now - before,
      top: [for (final e in top.take(5)) e.key],
    );
  }

  Map<String, dynamic> toJson() => {
    'days_logged': logged,
    'avg_kcal': avg.kcal.round(),
    'kcal_goal': targets.kcal.round(),
    'days_within_10pct_of_goal': onTarget,
    'avg_protein_g': avg.protein.round(),
    'protein_target_g': targets.protein.round(),
    'days_protein_hit': proteinDays,
    'avg_fibre_g': avg.fiber.round(),
    if (avg.micros[Micro.sodium] != null)
      'avg_sodium_mg': avg.micros[Micro.sodium]!.round(),
    if (weightChange != null)
      'weight_change_kg_vs_last_week': (weightChange! * 10).round() / 10,
    'most_logged_foods': top,
  };
}

class WeekSummary {
  const WeekSummary({
    required this.headline,
    required this.points,
    this.byAi = false,
  });

  final String headline;
  final List<String> points;
  final bool byAi;

  Map<String, dynamic> toJson() => {'h': headline, 'p': points};

  static WeekSummary? fromJson(Map<String, dynamic> j) {
    final h = j['h'] ?? j['headline'];
    final p = j['p'] ?? j['points'];
    if (h is! String || h.trim().isEmpty || p is! List) return null;
    final points = [
      for (final x in p)
        if (x is String && x.trim().isNotEmpty) x.trim(),
    ];
    if (points.isEmpty) return null;
    return WeekSummary(
      headline: h.trim(),
      points: points.take(4).toList(),
      byAi: true,
    );
  }

  /// Written from the numbers alone, no AI.
  factory WeekSummary.plain(WeekStats s, {bool metric = true}) {
    String n(double v) => v.round().toString();
    String k(double v) {
      final t = v.round().abs().toString();
      return t.length > 3
          ? '${t.substring(0, t.length - 3)},${t.substring(t.length - 3)}'
          : t;
    }

    final t = s.targets;
    final off = (s.avg.kcal - t.kcal) / t.kcal;
    final headline = off.abs() <= 0.1
        ? 'Close to goal all week'
        : off > 0
        ? 'Above goal on average'
        : 'Below goal on average';
    final points = [
      'Logged ${s.logged} of 7 days, averaging ${k(s.avg.kcal)} kcal against a ${k(t.kcal)} goal. '
          '${switch (s.onTarget) {
            0 => 'No day was',
            1 => 'One day was',
            final n => '$n days were',
          }} within 10%.',
      'Protein averaged ${n(s.avg.protein)} g of ${n(t.protein)} g, '
          '${s.proteinDays == 0 ? 'short of target every day' : 'reached on ${s.proteinDays} ${s.proteinDays == 1 ? 'day' : 'days'}'}.',
      if (s.weightChange != null)
        'Weight ${s.weightChange! <= 0 ? 'down' : 'up'} '
            '${metric ? '${s.weightChange!.abs().toStringAsFixed(1)} kg' : '${(s.weightChange!.abs() * 2.20462).toStringAsFixed(1)} lb'} '
            'on the week before.',
      if (s.avg.fiber < 20)
        'Fibre averaged ${n(s.avg.fiber)} g a day; 28 g is the daily value.',
    ];
    return WeekSummary(headline: headline, points: points);
  }

  static const _system = '''
You write a short weekly recap for a food logging app, from the stats given.
Rules:
- Use only the numbers given. Never invent or estimate new ones.
- Plain, warm, specific. No emoji, no exclamation marks, no moralising, no medical advice.
- Refer to their actual foods when it helps.
Return JSON: {"headline": string, "points": [string]}
- headline: at most 6 words.
- points: 3 items, each one sentence of at most 24 words. The first two say how the week went; the last is one concrete idea for next week.''';

  /// Words the recap with [client]; throws [AiException] on failure.
  static Future<WeekSummary> write(
    AiClient client,
    WeekStats s, {
    bool metric = true,
  }) async {
    final j = await client.json(
      _system,
      'Units: ${metric ? 'kg' : 'lb (weights given in kg, convert)'}\nStats: ${jsonEncode(s.toJson())}',
    );
    final w = fromJson(j);
    if (w == null) throw const AiException('The recap came back empty.');
    return w;
  }
}
