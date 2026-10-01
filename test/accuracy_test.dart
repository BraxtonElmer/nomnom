import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/meal_parser.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/nutrition/local_parser.dart';

import 'meal_parser_test.dart' show FakeAi;
import 'support/db.dart';

/// Precise inputs with known answers. Each case here was once wrong by
/// hundreds of kcal.
void main() {
  final db = loadTestDb();
  FoodDb.use(db);
  List<FoodItem>? local(String t, {FoodItem? Function(String)? recall}) =>
      LocalParser(db, country: 'IN', recall: recall ?? (_) => null).parse(t);

  Map<String, dynamic> item(
    String name,
    num qty,
    String unit,
    num grams,
    num kcal, {
    String? search,
    String? size,
  }) => {
    'name': name,
    'qty': qty,
    'unit': unit,
    'grams': grams,
    'search': search ?? name.toLowerCase(),
    'size': size,
    'kcal': kcal,
    'protein': 0,
    'carbs': 0,
    'fat': 0,
  };

  Future<FoodItem> viaAi(Map<String, dynamic> it, String id, {FoodItem? remembered}) async {
    final meal = await MealParser(
      FakeAi([
        {
          'title': it['name'],
          'items': [it],
        },
        {
          'matches': [
            {'item': 0, 'id': id},
          ],
        },
      ]),
      country: 'IN',
      recall: (_) => remembered,
    ).parse('x');
    return meal.items.single.item;
  }

  group('counted foods', () {
    test('a count of nuts or berries is pieces, never cups or handfuls', () {
      expect(local('10 almonds')!.single.total.kcal, closeTo(69, 2)); // 10 × 1.2 g
      expect(local('10 grapes')!.single.grams, closeTo(49, 1));
      expect(local('5 strawberries')!.single.grams, 60);
      expect(local('a handful of almonds')!.single.grams, 28);
      expect(local('3 papaya'), isNull); // no piece weight: the AI decides
    });

    test('the AI path uses the per-piece label, not "1 cup, whole"', () async {
      final a = await viaAi(item('Almond', 10, 'piece', 12, 70), 'usda:170567');
      expect(a.grams, closeTo(12, 0.1));
      final roasted = await viaAi(item('Almond', 22, 'piece', 28, 165), 'usda:170158');
      expect(roasted.grams, closeTo(28.4, 0.5)); // "1 oz (22 whole kernels)"
    });

    test('size words pick the size, not more pieces', () async {
      final eggs = await viaAi(
        item('Boiled egg', 2, 'piece', 100, 155, size: 'large'),
        'usda:173424',
      );
      expect(eggs.qty, 2);
      expect(eggs.total.kcal, closeTo(155, 1)); // 2 × 50 g
      expect(eggs.qtyLabel, '2 large pcs');

      final plain = await viaAi(item('Egg', 2, 'piece', 100, 143), 'usda:171287');
      expect(plain.grams, 100); // USDA's standard egg is large

      expect(local('large banana')!.single.grams, 136);
      expect(local('banana')!.single.grams, 118);
    });
  });

  group('servings and liquids', () {
    test('a serving only clamps to a real serving', () async {
      final almonds = await viaAi(item('Almonds', 1, 'serving', 28, 164), 'usda:170567');
      expect(almonds.grams, 28); // no serving label: the model's grams stand
    });

    test('ml of oil and honey are weighed by density', () {
      expect(local('15 ml olive oil')!.single.grams, closeTo(13.8, 0.1));
      expect(local('15 ml honey')!.single.total.kcal, closeTo(64.8, 1));
    });
  });

  group('memory and matching', () {
    test('a food remembered by weight comes back at its weight', () {
      const rice = FoodItem(
        name: 'Rice',
        qty: 150,
        unit: 'g',
        unitGrams: 1,
        per100: Nutrients(kcal: 130),
        source: Source.dish,
        ref: 'in-rice',
      );
      expect(local('rice', recall: (_) => rice)!.single.grams, 150);
      // An old memory saved at 1 g isn't trusted.
      expect(local('rice', recall: (_) => rice.copyWith(qty: 1))?.single.grams, isNot(1));
    });

    test('raw rice is not matched to cooked rice', () async {
      final meal = await MealParser(
        FakeAi([
          {
            'title': 'Rice',
            'items': [item('Rice', 100, 'g', 100, 365, search: 'rice white long-grain raw')],
          },
          {
            'matches': [
              {'item': 0, 'id': 'usda:169756'},
            ],
          },
        ]),
        country: 'IN',
        recall: (_) => null,
      ).parse('100g uncooked rice');
      expect(meal.items.single.item.total.kcal, closeTo(365, 1));
    });

    test('a remembered cooked food is not reused for a raw one', () async {
      const cooked = FoodItem(
        name: 'Rice',
        qty: 1,
        unit: 'g',
        unitGrams: 1,
        per100: Nutrients(kcal: 130),
        source: Source.dish,
        ref: 'in-rice',
      );
      final r = await viaAi(
        item('Rice', 100, 'g', 100, 365, search: 'rice white raw'),
        'usda:169756',
        remembered: cooked,
      );
      expect(r.total.kcal, closeTo(365, 1));
    });
  });

  group('editing', () {
    test('steppers move one notch from where they are', () {
      const egg = FoodItem(
        name: 'Egg',
        qty: 1.5,
        unit: 'piece',
        unitGrams: 50,
        per100: Nutrients(kcal: 143),
        source: Source.usda,
      );
      expect(egg.step(1).qty, 2);
      expect(egg.step(-1).qty, 1);
      expect(egg.copyWith(qty: 2).step(1).qty, 3);
      expect(egg.copyWith(qty: 155, unit: 'g', unitGrams: 1).step(1).qty, 160);
    });

    test('richness only moves dish-table recipes', () {
      const chicken = FoodItem(
        name: 'Chicken',
        qty: 200,
        unit: 'g',
        unitGrams: 1,
        per100: Nutrients(kcal: 165, fat: 10),
        source: Source.usda,
        richness: 1,
      );
      expect(chicken.total.kcal, 330);
    });
  });
}
