import '../data/models.dart';
import 'targets.dart';

/// One specific line about a plate, in the context of the rest of the day.
/// Rules over the user's own numbers, most useful first; never filler.
String plateNote({
  required Nutrients plate,
  required Nutrients restOfDay,
  required Targets targets,
  required Meal meal,
}) {
  final after = restOfDay + plate;
  final sodium = plate.micros[Micro.sodium];
  final daySodium = after.micros[Micro.sodium];
  final sugar = plate.micros[Micro.sugar];
  final proteinLeft = targets.protein - after.protein;
  final kcalLeft = targets.kcal - after.kcal;
  String n(double v) => v.round().toString();
  String k(double v) {
    final s = v.round().abs().toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}' : s;
  }

  if (kcalLeft < 0) {
    return 'This takes you ${k(-kcalLeft)} kcal over today’s goal.';
  }
  if (daySodium != null && daySodium > Micro.sodium.dv) {
    return 'Sodium is past today’s limit: ${k(daySodium)} mg of ${k(Micro.sodium.dv)}.';
  }
  if (sodium != null && sodium > Micro.sodium.dv * 0.4) {
    return 'Salty plate: ${k(sodium)} mg sodium, about ${n(sodium / Micro.sodium.dv * 100)}% of a day’s limit.';
  }
  if (plate.protein >= 30) {
    return proteinLeft > 5
        ? 'Good protein: ${n(plate.protein)} g. ${n(proteinLeft)} g to go today.'
        : 'Good protein: ${n(plate.protein)} g, and today’s protein goal is met.';
  }
  if (meal != Meal.snack && plate.kcal > 250 && plate.protein < plate.kcal * 0.1 / 4) {
    return 'Light on protein: ${n(plate.protein)} g. ${n(proteinLeft.clamp(0, 999))} g to go today.';
  }
  if (sugar != null && sugar > 25) {
    return '${n(sugar)} g sugar here, about half a day’s limit.';
  }
  if (plate.fiber >= 8) {
    return 'Plenty of fibre: ${n(plate.fiber)} g, ${n(plate.fiber / 28 * 100)}% of the day.';
  }
  return '${k(kcalLeft)} kcal and ${n(proteinLeft.clamp(0, 999))} g protein left for today after this.';
}
