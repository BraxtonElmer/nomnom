import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/ai/client.dart';
import 'package:nomnom/ai/meal_parser.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/food_db.dart';

/// Replays canned replies: first the parse, then the match.
class FakeAi extends AiClient {
  FakeAi(this.replies);
  final List<Map<String, dynamic>> replies;
  final prompts = <String>[];

  @override
  Future<Map<String, dynamic>> json(String system, String user) async {
    prompts.add(user);
    return replies.removeAt(0);
  }

  @override
  Future<List<String>> models() async => [];
}

void main() {
  FoodDb.use(
    FoodDb.fromRaw(
      File('assets/data/usda.json').readAsStringSync(),
      File('assets/data/dishes_in.json').readAsStringSync(),
    ),
  );

  test('chicken, rotis and dal resolve to table numbers', () async {
    final ai = FakeAi([
      {
        'title': 'Grilled chicken, 2 rotis, dal',
        'meal': null,
        'items': [
          {
            'name': 'grilled chicken breast',
            'qty': 120,
            'unit': 'g',
            'grams': 120,
            'search': 'chicken breast meat only cooked roasted',
            'kcal': 200,
            'protein': 37,
            'carbs': 0,
            'fat': 4,
            'fiber': 0,
          },
          {
            'name': 'Roti',
            'qty': 2,
            'unit': 'pieces',
            'grams': 70,
            'search': 'roti',
            'kcal': 210,
            'protein': 6,
            'carbs': 40,
            'fat': 3,
            'fiber': 4,
            'sodium_mg': 280,
          },
          {
            'name': 'Dal tadka',
            'qty': 1,
            'unit': 'bowl',
            'grams': 180,
            'search': 'dal tadka',
            'kcal': 200,
            'protein': 10,
            'carbs': 25,
            'fat': 6,
            'fiber': 4,
          },
          {
            'name': 'Mystery chutney',
            'qty': 1,
            'unit': 'tbsp',
            'grams': 15,
            'search': 'zzqx',
            'kcal': 20,
            'protein': 0,
            'carbs': 4,
            'fat': 0.5,
            'fiber': 0.5,
          },
        ],
      },
      {
        'matches': [
          {'item': 0, 'id': 'usda:171477'},
          {'item': 1, 'id': 'in-roti'},
          {'item': 2, 'id': 'in-dal-tadka'},
        ],
      },
    ]);
    final meal = await MealParser(
      ai,
      country: 'IN',
      recall: (_) => null,
    ).parse('120g grilled chicken, 2 rotis, a bowl of dal and some chutney');

    expect(meal.title, 'Grilled chicken, 2 rotis, dal');
    final items = meal.items.map((p) => p.item).toList();

    expect(items[0].name, 'Grilled chicken breast');
    expect(items[0].source, Source.usda);
    expect(items[0].total.kcal, closeTo(198, 1)); // 165 kcal/100g × 1.2

    expect(items[1].source, Source.dish);
    expect(items[1].unitGrams, 40); // table portion, not the model's 35 g guess
    expect(items[1].total.kcal, 240);

    // USDA brings real micronutrients; the dish table borrows the estimate's
    // (280 mg sodium over the model's 70 g, applied to the table's 80 g).
    expect(items[0].total.micros[Micro.potassium], greaterThan(200));
    expect(items[1].total.micros[Micro.sodium], closeTo(320, 0.5));
    expect(items[1].total.micros[Micro.iron], isNull);

    expect(items[2].grams, 200);
    expect(items[2].total.kcal, 230);

    expect(items[3].source, Source.ai); // no candidates → keeps the estimate
    expect(items[3].total.kcal, closeTo(20, 0.01));

    // candidates were offered to the matcher, the junk item wasn't
    expect(ai.prompts[1], contains('usda:171477'));
    expect(ai.prompts[1], isNot(contains('3. Mystery')));
    // Exact dish-table names skip the matching request entirely.
    expect(ai.prompts[1], isNot(contains('2. Dal tadka')));
  });

  test('remembered foods skip matching', () async {
    final ai = FakeAi([
      {
        'title': 'Roti',
        'items': [
          {
            'name': 'Roti',
            'qty': 3,
            'unit': 'piece',
            'grams': 120,
            'search': 'roti',
            'kcal': 300,
            'protein': 9,
            'carbs': 60,
            'fat': 4,
          },
        ],
      },
    ]);
    const mine = FoodItem(
      name: 'Roti',
      qty: 1,
      unit: 'piece',
      unitGrams: 35,
      per100: Nutrients(kcal: 280),
      source: Source.manual,
    );
    final meal = await MealParser(ai, country: 'IN', recall: (_) => mine).parse('3 rotis');
    expect(meal.items.single.item.total.kcal, closeTo(3 * 35 * 2.8, 0.01));
    expect(ai.prompts, hasLength(1));
  });

  test('model disagreeing wildly with the table gets flagged', () async {
    final ai = FakeAi([
      {
        'title': 'Samosa',
        'items': [
          {
            'name': 'Samosa',
            'qty': 1,
            'unit': 'piece',
            'grams': 80,
            'search': 'samosa',
            'kcal': 900,
            'protein': 5,
            'carbs': 30,
            'fat': 15,
          },
        ],
      },
      {
        'matches': [
          {'item': 0, 'id': 'in-samosa'},
        ],
      },
    ]);
    final meal = await MealParser(ai, country: 'IN', recall: (_) => null).parse('samosa');
    expect(meal.items.single.item.flagged, isTrue);
  });

  test('extractJson tolerates fences and think blocks', () {
    expect(extractJson('<think>hmm</think>```json\n{"a":1}\n```')['a'], 1);
    expect(() => extractJson('nope'), throwsA(isA<AiException>()));
  });

  test('a vague amount comes back as one question with options', () async {
    final ai = FakeAi([
      {
        'title': 'Rice and rajma',
        'items': [
          {'name': 'Rajma', 'qty': 1, 'unit': 'bowl', 'grams': 200, 'search': 'rajma',
           'kcal': 250, 'protein': 13, 'carbs': 32, 'fat': 8},
        ],
        'ask': {'question': 'How much rice?', 'options': ['Small bowl', '1 cup', 'Full plate', '']},
      },
    ]);
    final meal = await MealParser(ai, country: 'IN', recall: (_) => null).parse('rice and rajma');
    expect(meal.question, 'How much rice?');
    expect(meal.options, ['Small bowl', '1 cup', 'Full plate']);
  });
}
