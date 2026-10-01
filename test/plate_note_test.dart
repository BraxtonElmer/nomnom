import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/plate_note.dart';
import 'package:nomnom/nutrition/targets.dart';

void main() {
  final t = Targets.of(
    const Profile(
      sex: Sex.male,
      age: 30,
      heightCm: 178,
      weightKg: 80,
      activity: 1.375,
      customKcal: 2000,
    ),
  );
  String note(Nutrients plate, {Nutrients rest = Nutrients.zero, Meal meal = Meal.lunch}) =>
      plateNote(plate: plate, restOfDay: rest, targets: t, meal: meal);

  test('going over the goal comes first', () {
    expect(
      note(const Nutrients(kcal: 700), rest: const Nutrients(kcal: 1500)),
      'This takes you 200 kcal over today’s goal.',
    );
  });

  test('salt, protein, sugar and fibre each get a specific line', () {
    expect(
      note(const Nutrients(kcal: 500, protein: 20, micros: {Micro.sodium: 1200})),
      startsWith('Salty plate: 1,200 mg'),
    );
    expect(note(const Nutrients(kcal: 500, protein: 37)), startsWith('Good protein: 37 g.'));
    expect(note(const Nutrients(kcal: 600, protein: 8)), startsWith('Light on protein: 8 g.'));
    expect(
      note(const Nutrients(kcal: 200, protein: 3, micros: {Micro.sugar: 30}), meal: Meal.snack),
      startsWith('30 g sugar'),
    );
    expect(note(const Nutrients(kcal: 220, protein: 12, fiber: 10)), startsWith('Plenty of fibre'));
  });

  test('otherwise it says what is left for the day', () {
    expect(
      note(const Nutrients(kcal: 200, protein: 15), meal: Meal.snack),
      '1,800 kcal and ${(t.protein - 15).round()} g protein left for today after this.',
    );
  });
}
