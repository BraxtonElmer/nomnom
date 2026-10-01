import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/targets.dart';
import 'package:nomnom/nutrition/week_summary.dart';

import 'meal_parser_test.dart' show FakeAi;

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
  final monday = DateTime(2026, 9, 21);

  Entry day(int i, double kcal, double protein) => Entry(
    id: '$i',
    at: monday.add(Duration(days: i, hours: 13)),
    meal: Meal.lunch,
    title: 'Dal rice',
    text: 'dal rice',
    items: [
      FoodItem(
        name: i.isEven ? 'Dal' : 'Rice',
        qty: 100,
        unit: 'g',
        unitGrams: 1,
        per100: Nutrients(kcal: kcal, protein: protein, fiber: 5),
        source: Source.dish,
      ),
    ],
  );

  WeekStats? stats(List<Entry> es, {List<WeightEntry> weights = const []}) => WeekStats.compute(
    start: monday,
    entriesOn: (d) => es.where((e) => dayOf(e.at) == d).toList(),
    targets: t,
    weights: weights,
  );

  test('needs three logged days', () {
    expect(stats([day(0, 2000, 150), day(1, 2000, 150)]), isNull);
  });

  test('stats and the plain recap come from the log', () {
    final s = stats(
      [day(0, 2000, 160), day(2, 2100, 100), day(4, 2600, 100)],
      weights: [
        WeightEntry(day: monday.subtract(const Duration(days: 3)), kg: 80),
        WeightEntry(day: monday.add(const Duration(days: 2)), kg: 79.6),
      ],
    )!;
    expect(s.logged, 3);
    expect(s.avg.kcal, closeTo(2233, 1));
    expect(s.onTarget, 2);
    expect(s.weightChange, closeTo(-0.4, 0.01));
    expect(s.top, ['dal']);
    final w = WeekSummary.plain(s);
    expect(w.headline, 'Above goal on average');
    expect(w.points.first, startsWith('Logged 3 of 7 days, averaging 2,233 kcal'));
    expect(w.points, contains('Weight down 0.4 kg on the week before.'));
  });

  test('the AI only words the recap; empty replies are rejected', () async {
    final s = stats([day(0, 2000, 160), day(1, 1900, 150), day(2, 2050, 155)])!;
    final ai = FakeAi([
      {'headline': 'A steady week', 'points': ['One.', 'Two.', 'Three.']},
      {'headline': '', 'points': []},
    ]);
    final w = await WeekSummary.write(ai, s);
    expect(w.headline, 'A steady week');
    expect(w.points, hasLength(3));
    expect(ai.prompts.first, contains('"avg_kcal":1983'));
    expect(() => WeekSummary.write(ai, s), throwsA(anything));
  });
}
