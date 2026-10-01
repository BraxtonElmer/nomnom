import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/check_in.dart';
import 'package:nomnom/nutrition/targets.dart';

void main() {
  const profile = Profile(
    sex: Sex.male,
    age: 30,
    heightCm: 178,
    weightKg: 80,
    activity: 1.55,
    goal: Goal.lose,
    paceKg: 0.5,
  );
  final today = DateTime(2026, 10, 1);
  final formula = Targets.of(profile).maintenance; // ≈ 2,760

  Map<DateTime, double> eating(double kcal, {int days = 28}) => {
    for (var d = 1; d <= days; d++) today.subtract(Duration(days: d)): kcal,
  };
  List<WeightEntry> losing(double kgPerWeek) => [
    for (var d = 28; d >= 1; d -= 3)
      WeightEntry(
        day: today.subtract(Duration(days: d)),
        kg: 80 - kgPerWeek * (28 - d) / 7,
      ),
  ];

  test('steady weight on less food than the formula expects lowers maintenance', () {
    final c = CheckIn.compute(
      profile: profile,
      kcalByDay: eating(2300),
      weights: losing(0),
      today: today,
    )!;
    expect(c.measured, closeTo(2300, 10));
    expect(c.current, closeTo(formula, 1));
    expect(c.newTarget, closeTo(2300 - 550, 10)); // keeps the 0.5 kg/week pace
  });

  test('losing weight while eating adds the deficit back', () {
    final c = CheckIn.compute(
      profile: profile,
      kcalByDay: eating(2000),
      weights: losing(0.5),
      today: today,
    )!;
    // 0.5 kg a week ≈ 550 kcal a day below maintenance; smoothing lags a little.
    expect(c.measured, inInclusiveRange(2350, 2560));
  });

  test('stays quiet when the formula already fits', () {
    expect(
      CheckIn.compute(
        profile: profile,
        kcalByDay: eating(formula),
        weights: losing(0),
        today: today,
      ),
      isNull,
    );
  });

  test('needs enough logged days and weigh-ins', () {
    expect(
      CheckIn.compute(
        profile: profile,
        kcalByDay: eating(2300, days: 6),
        weights: losing(0),
        today: today,
      ),
      isNull,
    );
    expect(
      CheckIn.compute(
        profile: profile,
        kcalByDay: eating(2300),
        weights: losing(0).take(1).toList(),
        today: today,
      ),
      isNull,
    );
    // Barely-logged days look like undereating; they're ignored.
    expect(
      CheckIn.compute(profile: profile, kcalByDay: eating(600), weights: losing(0), today: today),
      isNull,
    );
  });

  test('accepting it changes targets through learned maintenance', () {
    final next = profile.copyWith(learnedMaintenance: () => 2300);
    expect(Targets.of(next).maintenance, 2300);
    expect(Profile.fromJson(next.toJson()).learnedMaintenance, 2300);
  });
}
