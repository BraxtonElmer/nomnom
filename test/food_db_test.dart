import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/nutrition/food_db.dart';

void main() {
  final db = FoodDb.fromRaw(
    File('assets/data/usda.json').readAsStringSync(),
    File('assets/data/dishes_in.json').readAsStringSync(),
  );

  void top(String q, String want, {String? country = 'IN'}) {
    final hits = db.search(q, country: country);
    // ignore: avoid_print
    print('$q -> ${hits.take(3).map((h) => h.name).join(' | ')}');
    expect(hits.take(5).map((h) => h.name.toLowerCase()).any((n) => n.contains(want)), isTrue,
        reason: '"$q" should surface "$want"');
  }

  test('loads both tables', () => expect(db.size, greaterThan(7000)));

  test('common foods surface the right candidates', () {
    top('chicken breast roasted', 'breast');
    top('roti', 'roti');
    top('dal tadka', 'dal tadka');
    top('rice white cooked', 'rice, white');
    top('banana', 'banana');
    top('almonds', 'almonds');
    top('egg boiled', 'hard-boiled');
    top('chapati', 'roti');
    top('whole milk', 'milk');
    top('peanut butter', 'peanut butter');
    top('oats', 'oat');
    top('apple', 'apple');
  });
}
