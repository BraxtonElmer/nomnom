import 'dart:math' as math;

import '../data/models.dart';
import 'targets.dart';

/// What your own numbers say about your maintenance calories.
///
/// Energy balance: if you averaged [avgIntake] a day and your weight trend
/// moved by [trendKgPerWeek], then what you burn is roughly
/// intake − change × 7700 kcal/kg. Only offered as a suggestion; nothing
/// changes until the user accepts it.
class CheckIn {
  const CheckIn({
    required this.days,
    required this.loggedDays,
    required this.avgIntake,
    required this.trendKgPerWeek,
    required this.measured,
    required this.current,
    required this.newTarget,
  });

  final int days;
  final int loggedDays;
  final double avgIntake;
  final double trendKgPerWeek;

  /// Maintenance implied by the logs.
  final double measured;

  /// Maintenance the app currently uses.
  final double current;

  /// Daily target if the measured maintenance is accepted.
  final int newTarget;

  static const window = 28;
  static const minLoggedDays = 10;
  static const minWeighInSpan = 10;

  /// Null when there isn't enough trustworthy data, or the measured value is
  /// close enough to the current one that changing it would be noise.
  static CheckIn? compute({
    required Profile profile,
    required Map<DateTime, double> kcalByDay,
    required List<WeightEntry> weights,
    required DateTime today,
  }) {
    final end = dayOf(today); // today is still in progress; leave it out
    final start = addDays(end, -window);
    final target = Targets.of(profile).kcal;

    // Days logged so lightly they were probably incomplete would make intake
    // look smaller than it was, so they don't count.
    final intakes = [
      for (final e in kcalByDay.entries)
        if (!e.key.isBefore(start) && e.key.isBefore(end) && e.value >= target * 0.5) e.value,
    ];
    if (intakes.length < minLoggedDays) return null;

    final inWindow = weights.where((w) => !w.day.isBefore(start) && !w.day.isAfter(end)).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    if (inWindow.length < 2) return null;
    final span = daysBetween(inWindow.first.day, inWindow.last.day);
    if (span < minWeighInSpan) return null;

    // A straight line through every weigh-in, so one heavy or light morning
    // doesn't decide, and sparse weigh-ins don't lag the way smoothing does.
    final perDay = slopePerDay(inWindow);

    final avg = intakes.reduce((a, b) => a + b) / intakes.length;
    final measured = avg - perDay * 7700;
    final current = Targets.of(profile).maintenance;
    if (measured < 1000 || measured > 5000) return null;
    if ((measured - current).abs() < math.max(100, current * 0.07)) return null;

    final rounded = (measured / 10).round() * 10.0;
    final next = profile.copyWith(learnedMaintenance: () => rounded, customKcal: () => null);
    return CheckIn(
      days: window,
      loggedDays: intakes.length,
      avgIntake: avg,
      trendKgPerWeek: perDay * 7,
      measured: rounded,
      current: current,
      newTarget: suggestedKcal(next, rounded),
    );
  }
}

/// Least-squares weight change per day through [ws].
double slopePerDay(List<WeightEntry> ws) {
  if (ws.length < 2) return 0;
  final x0 = ws.first.day;
  final xs = [for (final w in ws) daysBetween(x0, w.day).toDouble()];
  final mx = xs.reduce((a, b) => a + b) / xs.length;
  final my = ws.fold(0.0, (s, w) => s + w.kg) / ws.length;
  var num = 0.0;
  var den = 0.0;
  for (var i = 0; i < ws.length; i++) {
    num += (xs[i] - mx) * (ws[i].kg - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  return den == 0 ? 0 : num / den;
}
