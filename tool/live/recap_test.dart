// Live check of the weekly recap wording. One free-tier request.
//
//   GEMINI_KEY=... MODEL=gemini-3.5-flash-lite flutter test tool/live/recap_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/client.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/targets.dart';
import 'package:nomnom/nutrition/week_summary.dart';

void main() {
  final key = Platform.environment['GEMINI_KEY'] ?? '';
  final model = Platform.environment['MODEL'] ?? 'gemini-3.5-flash-lite';

  test('live recap', () async {
    if (key.isEmpty) return markTestSkipped('set GEMINI_KEY');
    final t = Targets.of(const Profile(customKcal: 2000));
    final monday = DateTime(2026, 9, 21);
    FoodItem f(String name, double kcal, double protein) => FoodItem(
      name: name,
      qty: 100,
      unit: 'g',
      unitGrams: 1,
      per100: Nutrients(kcal: kcal, protein: protein, fiber: 3),
      source: Source.dish,
    );
    final log = {
      0: [f('Masala dosa', 1100, 25), f('Chicken biryani', 1200, 45)],
      1: [f('Poha', 600, 12), f('Paneer butter masala', 1300, 40)],
      3: [f('Masala dosa', 1100, 25), f('Dal', 500, 25), f('Rice', 700, 14)],
      5: [f('Chicken biryani', 1200, 45), f('Lassi', 400, 12), f('Poha', 600, 12)],
    };
    final s = WeekStats.compute(
      start: monday,
      entriesOn: (d) {
        final i = d.difference(monday).inDays;
        return [
          if (log[i] != null)
            Entry(id: '$i', at: d, meal: Meal.lunch, title: '', text: '', items: log[i]!),
        ];
      },
      targets: t,
      weights: [
        WeightEntry(day: monday.subtract(const Duration(days: 4)), kg: 82.4),
        WeightEntry(day: monday.add(const Duration(days: 3)), kg: 82.1),
      ],
    )!;
    final w = await WeekSummary.write(Gemini(key, model), s);
    // ignore: avoid_print
    print('${w.headline}\n- ${w.points.join('\n- ')}');
  });
}
