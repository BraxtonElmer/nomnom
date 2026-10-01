// ignore_for_file: invalid_use_of_visible_for_testing_member
// Live accuracy check: weighed and counted inputs with known USDA answers,
// run through the whole pipeline. Spends real free-tier requests (up to two
// per line), so it is never part of `flutter test`.
//
//   GEMINI_KEY=... MODEL=gemini-3.5-flash-lite flutter test tool/live/precise_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/client.dart';
import 'package:nomnom/ai/meal_parser.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/nutrition/open_food_facts.dart';
import '../../test/support/db.dart';

// Weighed or countable inputs with known USDA answers (expected kcal).
const sentences = [
  '150g cooked white rice and 120g grilled chicken breast', // 195 + ~190
  '200 ml whole milk with 1 tsp sugar', // 126 + 16
  '100g boiled chickpeas', // 164
  '1 medium banana and 30g almonds', // 105 + 174
  '40g rolled oats cooked in 200ml whole milk', // 152 + 126
  '150g boiled potatoes', // 130
  '2 large boiled eggs', // 155
  '2 slices whole wheat bread', // ~160
  '10 almonds', // 69
  '1 large banana', // 121
  '15 ml olive oil', // 122
  '100g uncooked basmati rice', // ~360
  '1 serving of almonds', // ~164 (28 g)
  '3 egg omelette with 1 tsp butter', // 215 + 36
];

void main() {
  final key = Platform.environment['GEMINI_KEY'] ?? '';
  final model = Platform.environment['MODEL'] ?? 'gemini-2.5-flash';
  final only = int.tryParse(Platform.environment['ONLY'] ?? '');

  test('live parse', () async {
    if (key.isEmpty) return markTestSkipped('set GEMINI_KEY');
    FoodDb.use(loadTestDb());
    final parser = MealParser(
      Gemini(key, model),
      country: Platform.environment['COUNTRY'] ?? 'IN',
      recall: (_) => null,
      packaged: (t, c) => OpenFoodFacts.search(t, country: c),
    );
    final text = Platform.environment['TEXT'];
    final list = text != null ? [text] : (only == null ? sentences : [sentences[only]]);
    for (final s in list) {
      final sw = Stopwatch()..start();
      try {
        final meal = await parser.parse(s);
        final total = meal.items.fold(Nutrients.zero, (a, p) => a + p.item.total);
        stdout.writeln('\n“$s”  →  ${meal.title}  [${sw.elapsedMilliseconds} ms]');
        for (final p in meal.items) {
          final i = p.item;
          stdout.writeln(
            '  ${i.name.padRight(28)} ${i.qtyLabel.padRight(9)} '
            '${i.grams.round().toString().padLeft(4)} g  '
            '${i.total.kcal.round().toString().padLeft(4)} kcal  '
            'P${i.total.protein.round()} C${i.total.carbs.round()} F${i.total.fat.round()}  '
            '${i.source.label}${i.flagged ? ' ⚑' : ''}  ${i.refName ?? ''}  '
            '(AI said ${p.estimate.total.kcal.round()})',
          );
        }
        stdout.writeln('  TOTAL ${total.kcal.round()} kcal');
        if (meal.question != null) stdout.writeln('  ASK ${meal.question} ${meal.options}');
      } on AiException catch (e) {
        stdout.writeln('\n“$s”  →  ERROR ${e.message}');
      }
      if (list.length > 1) await Future.delayed(const Duration(seconds: 13));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
