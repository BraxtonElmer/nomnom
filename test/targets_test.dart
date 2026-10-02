import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/targets.dart';

void main() {
  const p = Profile(sex: Sex.male, age: 30, heightCm: 180, weightKg: 80, activity: 1.55);

  test('mifflin st jeor', () {
    expect(bmr(p), 10 * 80 + 6.25 * 180 - 5 * 30 + 5);
  });

  test('losing 0.5 kg a week is a 550 kcal deficit', () {
    final lose = Targets.of(p.copyWith(goal: Goal.lose, paceKg: 0.5));
    expect(lose.kcal, closeTo(tdee(p) - 550, 10));
  });

  test('custom target overrides the suggestion and drives macros', () {
    final t = Targets.of(p.copyWith(customKcal: () => 2000, macros: MacroPreset.highProtein));
    expect(t.kcal, 2000);
    expect(t.protein, 175);
    expect(t.suggested, isNot(2000));
  });

  test('never suggests below the floor', () {
    final tiny = Targets.of(
      const Profile(
        sex: Sex.female,
        age: 60,
        heightCm: 150,
        weightKg: 45,
        activity: 1.2,
        goal: Goal.lose,
        paceKg: 1,
      ),
    );
    expect(tiny.kcal, 1200);
  });

  test('item scaling is exact', () {
    const roti = FoodItem(
      name: 'Roti',
      qty: 2,
      unit: 'piece',
      unitGrams: 40,
      per100: Nutrients(kcal: 300, protein: 9.6),
      source: Source.dish,
    );
    expect(roti.total.kcal, 240);
    expect(roti.step(1).qty, 3);
    expect(roti.qtyLabel, '2 pcs');
  });

  test('bmi uses asian cut-offs where they apply', () {
    expect(bmiOf(74, 176), closeTo(23.9, 0.05));
    expect(bmiBand(23.9, 'IN'), 'Overweight');
    expect(bmiBand(23.9, 'US'), 'Healthy range');
    expect(bmiBand(17, 'GB'), 'Underweight');
  });

  test('richer home cooking adds fat and its calories', () {
    const dal = FoodItem(
      name: 'Dal',
      qty: 1,
      unit: 'bowl',
      unitGrams: 200,
      per100: Nutrients(kcal: 110, protein: 6, carbs: 15, fat: 3),
      source: Source.dish,
    );
    expect(dal.total.kcal, 220);
    final rich = dal.copyWith(richness: 1);
    expect(rich.total.fat, closeTo(6 * 1.35, 0.001));
    expect(rich.total.kcal, closeTo(220 + 6 * 0.35 * 9, 0.001));
    expect(FoodItem.fromJson(rich.toJson()).richness, 1);
    expect(dal.copyWith(richness: -1).total.kcal, lessThan(220));
  });

  test('body weight keeps its decimal', () {
    expect(kg(75.5, true), '75.5 kg');
    expect(kg(74, true), '74 kg');
    expect(weightText(75.5, true), '75.5');
    expect(weightText(70, false), '154.3');
  });
}
