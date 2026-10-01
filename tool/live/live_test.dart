// ignore_for_file: invalid_use_of_visible_for_testing_member
// Live check against a real model. Spends real free-tier requests (two per
// sentence), so it is never part of `flutter test`.
//
//   GEMINI_KEY=... MODEL=gemini-2.5-flash flutter test tool/live
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/client.dart';
import 'package:nomnom/ai/meal_parser.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/nutrition/open_food_facts.dart';
import '../../test/support/db.dart';

const sentences = [
  '120g grilled chicken, 2 rotis and a bowl of dal',
  'masala dosa with sambar and coconut chutney',
  '2 boiled eggs and a slice of brown bread with butter',
  'chicken biryani, one plate, and a raita',
  'a glass of amul lassi',
  'cup of chai with 2 marie biscuits',
  'paneer butter masala with 2 butter naan',
  'banana and a handful of almonds',
  'poha',
  '200 ml full cream milk with 1 tsp sugar',
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
