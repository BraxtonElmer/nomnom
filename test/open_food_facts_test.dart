import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/client.dart';
import 'package:nomnom/ai/meal_parser.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/nutrition/open_food_facts.dart';
import 'support/db.dart';

class _OneShot extends AiClient {
  _OneShot(this.replies);
  final List<Map<String, dynamic>> replies;
  final prompts = <String>[];
  final photos = <Photo?>[];

  @override
  Future<Map<String, dynamic>> json(String system, String user, {Photo? photo}) async {
    photos.add(photo);
    prompts.add(user);
    return replies.removeAt(0);
  }

  @override
  Future<List<String>> models() async => [];
}

void main() {
  // A real search.openfoodfacts.org reply for “amul lassi” in India.
  final hits = OpenFoodFacts.parse(File('test/off_sample.json').readAsStringSync());

  test('parses products, skipping ones without energy', () {
    expect(hits.map((h) => h.name), contains('Amul Lassi'));
    expect(hits.every((h) => h.per100.kcal > 0), isTrue);
    final lassi = hits.firstWhere((h) => h.id == 'off:8901262202046');
    expect(lassi.source, Source.off);
    expect(lassi.per100.kcal, 142);
    expect(lassi.per100.micros[Micro.sugar], 22.5);
    expect(lassi.per100.micros[Micro.sodium], closeTo(52, 0.01)); // g → mg
  });

  test('a named brand pulls packaged candidates into matching', () async {
    FoodDb.use(loadTestDb());
    final ai = _OneShot([
      {
        'title': 'Amul lassi',
        'items': [
          {
            'name': 'Amul lassi',
            'qty': 200,
            'unit': 'ml',
            'grams': 200,
            'search': 'lassi',
            'brand': 'Amul',
            'kcal': 200,
            'protein': 6,
            'carbs': 30,
            'fat': 6,
          },
        ],
      },
      {
        'matches': [
          {'item': 0, 'id': 'off:8901262202046'},
        ],
      },
    ]);
    String? searched;
    final meal = await MealParser(
      ai,
      country: 'IN',
      recall: (_) => null,
      packaged: (t, c) async {
        searched = t;
        return hits;
      },
    ).parse('a glass of amul lassi');

    expect(searched, 'Amul lassi');
    expect(ai.prompts[1], contains('off:8901262202046'));
    final item = meal.items.single.item;
    expect(item.source, Source.off);
    expect(item.total.kcal, closeTo(284, 0.5));
  });

  test('a pack is the whole pack, and prepared values are their own match', () {
    final foods = OpenFoodFacts.parse(
      '{"hits": [{"code": "1", "product_name": "Masala noodles",'
      ' "brands": "Maggi", "serving_quantity": 70, "product_quantity": "280",'
      ' "nutriments": {"energy-kcal_100g": 430, "proteins_100g": 9,'
      ' "energy-kcal_prepared_100g": 95, "proteins_prepared_100g": 2}}]}',
    );
    expect(foods.map((f) => f.id), ['off:1', 'off:1:prep']);
    expect(foods.first.portions, [('1 serving', 70.0), ('1 pack', 280.0)]);
    expect(foods.last.name, 'Maggi Masala noodles (as prepared)');
    expect(foods.last.per100.kcal, 95);
    expect(foods.last.portions, isEmpty);
  });
}
