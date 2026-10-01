import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/nutrition/local_parser.dart';

import 'support/db.dart';

void main() {
  final db = loadTestDb();
  List<FoodItem>? read(String t, {FoodItem? Function(String)? recall}) =>
      LocalParser(db, country: 'IN', recall: recall ?? (_) => null).parse(t);

  test('reads simple meals entirely on the phone', () {
    final a = read('2 rotis and a bowl of dal')!;
    expect(a.map((i) => i.ref), ['in-roti', 'in-dal']);
    expect(a[0].total.kcal, 240);
    expect(a[0].qtyLabel, '2 pcs');
    expect(a[1].grams, 200);

    final b = read('banana, 200 ml milk, 1 tsp sugar')!;
    expect(b.map((i) => i.ref), ['usda:173944', 'usda:171265', 'usda:169655']);
    expect(b[1].grams, 200);

    expect(read('poha')!.single.ref, 'in-poha');
    expect(read('dal 1 bowl')!.single.grams, 200);
    expect(read('had 3 idli with sambar for breakfast')!.map((i) => i.ref), [
      'in-idli',
      'in-sambar',
    ]);
    expect(read('veg hakka noodles')!.single.ref, 'in-hakka-noodles');
    expect(read('2 slices brown bread')!.single.grams, 64);
    expect(read('margherita pizza 2 slices')!.single.grams, 220);
  });

  test('anything unclear goes to the AI', () {
    expect(read('some rice'), isNull); // vague amount: the AI can ask
    expect(read('grilled chicken'), isNull); // not a confident table match
    expect(read('2 rotis and grilled chicken'), isNull); // one unknown part sends all
    expect(read('a glass of amul lassi'), isNull); // brands need Open Food Facts
    expect(read('2 bowls of roti'), isNull); // unit the table doesn't know for it
  });

  test('foods confirmed before are read from memory', () {
    const mine = FoodItem(
      name: 'Grilled chicken',
      qty: 1,
      unit: 'g',
      unitGrams: 1,
      per100: Nutrients(kcal: 165),
      source: Source.usda,
      ref: 'usda:171477',
    );
    final items = read(
      '150g grilled chicken',
      recall: (n) => n == 'grilled chicken' ? mine : null,
    )!;
    expect(items.single.total.kcal, closeTo(247.5, 0.01));
  });
}
