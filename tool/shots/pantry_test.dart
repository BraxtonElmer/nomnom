import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/data/pantry.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/screens/log/review_screen.dart';
import 'package:nomnom/screens/pantry/pantry_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
    final now = DateTime.now();
    final day = dayOf(now).subtract(const Duration(days: 20));
    for (final s in [
      StockItem(
        id: 'eggs',
        name: 'Eggs',
        unit: 'piece',
        left: 8,
        full: 12,
        added: day,
        ref: 'usda:171287',
        pieceGrams: 50,
      ),
      StockItem(
        id: 'chicken',
        name: 'Chicken breast',
        unit: 'g',
        left: 200,
        full: 900,
        added: day,
        useBy: dayOf(now).add(const Duration(days: 1)),
      ),
      StockItem(id: 'milk', name: 'Milk', unit: 'ml', left: 1500, full: 2000, added: day),
      StockItem(
        id: 'yogurt',
        name: 'Greek yogurt',
        unit: 'g',
        left: 0,
        full: 500,
        added: day,
        raw: false,
      ),
    ]) {
      await Store.i.putStock(s);
    }
  });

  testWidgets('pantry', (t) => shoot(t, 'pantry', const Scaffold(body: PantryScreen())));
  testWidgets(
    'pantry dark',
    (t) => shoot(t, 'pantry_dark', const Scaffold(body: PantryScreen()), dark: true),
  );

  testWidgets('review with pantry', (t) async {
    final e = Entry(
      id: 'shot-pantry',
      at: DateTime.now(),
      meal: Meal.lunch,
      title: 'Chicken and eggs',
      text: '250g chicken breast and 2 boiled eggs',
      items: [
        dbItem('usda:171077', 'Chicken breast', 250, 'g', 1),
        dbItem('usda:173424', 'Boiled egg', 2, 'piece', 50),
      ],
      stock: const {},
    );
    await shoot(t, 'review_pantry', ReviewScreen.edit(entry: e));
  });
}
