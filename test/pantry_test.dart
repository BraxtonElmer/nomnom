import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/data/pantry.dart';
import 'package:nomnom/data/store.dart';

import 'support/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  setUpAll(() => Store.i.init(path: Directory.systemTemp.createTempSync('nomnom_pantry').path));

  final day = DateTime(2026, 10, 1);
  final eggs = StockItem(
    id: 'eggs',
    name: 'Eggs',
    unit: 'piece',
    left: 10,
    full: 10,
    added: day,
    ref: 'usda:171287',
    pieceGrams: 50,
  );
  final chicken = StockItem(
    id: 'chicken',
    name: 'Chicken breast',
    unit: 'g',
    left: 450,
    full: 450,
    added: day,
    ref: 'usda:171077',
  );

  FoodItem food(
    String name,
    double qty,
    String unit, {
    double unitGrams = 1,
    String? ref,
    String? refName,
    Source source = Source.usda,
  }) => FoodItem(
    name: name,
    qty: qty,
    unit: unit,
    unitGrams: unitGrams,
    per100: const Nutrients(kcal: 150),
    source: source,
    ref: ref,
    refName: refName,
  );

  final at = DateTime(2026, 10, 1, 13);

  group('planning', () {
    test('the same food counts straight down', () {
      final p = planStock(
        [food('Egg', 2, 'piece', unitGrams: 50, ref: 'usda:171287')],
        [eggs],
        at: at,
      );
      expect(p.single.ask, isNull);
      expect(p.single.amount, 2);
    });

    test('a look-alike food is asked once before it counts', () {
      final boiled = food('Boiled egg', 2, 'piece', unitGrams: 50, ref: 'usda:173424');
      expect(planStock([boiled], [eggs], at: at).single.ask, StockAsk.link);
      final linked = eggs.copyWith(links: {'boiled egg'});
      expect(planStock([boiled], [linked], at: at).single.ask, isNull);
      final never = eggs.copyWith(unlinks: {'boiled egg'});
      expect(planStock([boiled], [never], at: at), isEmpty);
    });

    test('cooked meat is converted back to raw weight', () {
      final grilled = food(
        'Grilled chicken',
        250,
        'g',
        ref: 'usda:171477',
        refName: 'Chicken, broiler, breast, meat only, cooked, grilled',
      );
      final p = planStock(
        [grilled],
        [
          chicken.copyWith(links: {'grilled chicken'}),
        ],
        at: at,
      ).single;
      expect(p.ask, isNull);
      expect(p.amount, 333);
      expect(p.note, '250 g cooked ≈ 333 g raw');
    });

    test('unsaid raw or cooked, and mixed dishes, are asked', () {
      final plain = food('Chicken breast', 250, 'g', ref: 'usda:171077', refName: 'Chicken breast');
      final p = planStock([plain], [chicken], at: at).single;
      expect(p.ask, StockAsk.amount);
      expect(p.suggested, 250);

      final biryani = food(
        'Chicken biryani',
        1,
        'plate',
        unitGrams: 300,
        source: Source.dish,
        ref: 'in-chicken-biryani',
      );
      final q = planStock(
        [biryani],
        [
          chicken.copyWith(links: {'chicken biryani'}),
        ],
        at: at,
      ).single;
      expect(q.ask, StockAsk.amount);
      expect(q.amount, isNull);
    });

    test('taking more than is left asks, offering what is there', () {
      final p = planStock(
        [food('Egg', 3, 'piece', unitGrams: 50, ref: 'usda:171287')],
        [eggs.copyWith(left: 2)],
        at: at,
      ).single;
      expect(p.ask, StockAsk.short);
      expect(p.amount, 2);
    });

    test('meals from before the stock was added are left alone', () {
      final p = planStock(
        [food('Egg', 2, 'piece', ref: 'usda:171287')],
        [eggs],
        at: DateTime(2026, 9, 30, 9),
      );
      expect(p, isEmpty);
    });
  });

  group('store', () {
    Entry meal(String id, List<FoodItem> items) =>
        Entry(id: id, at: at, meal: Meal.lunch, title: 'x', text: 'x', items: items);
    final twoEggs = food('Egg', 2, 'piece', unitGrams: 50, ref: 'usda:171287');

    test('logging, editing, deleting and undoing move stock', () async {
      await Store.i.putStock(eggs);
      await Store.i.putEntry(meal('m1', [twoEggs]));
      expect(Store.i.stockItem('eggs')!.left, 8);

      final saved = Store.i.entry('m1')!;
      await Store.i.putEntry(
        saved.copyWith(items: [twoEggs.copyWith(qty: 3)], stock: () => {'eggs': 3}),
      );
      expect(Store.i.stockItem('eggs')!.left, 7);

      await Store.i.deleteEntry('m1');
      expect(Store.i.stockItem('eggs')!.left, 10);

      await Store.i.putEntry(Store.i.entry('m1') ?? saved.copyWith(stock: () => {'eggs': 3}));
      expect(Store.i.stockItem('eggs')!.left, 7);
      await Store.i.deleteEntry('m1');
    });

    test('copies take from stock again; unclear ones wait for the user', () async {
      final e = meal('m2', [twoEggs]);
      await Store.i.putEntry(e);
      final copies = await Store.i.copyTo([Store.i.entry('m2')!], DateTime(2026, 10, 2));
      expect(Store.i.stockItem('eggs')!.left, 6);
      await Store.i.deleteEntry(copies.single.id);
      await Store.i.deleteEntry('m2');
      expect(Store.i.stockItem('eggs')!.left, 10);

      await Store.i.putEntry(meal('m3', [food('Boiled egg', 2, 'piece', ref: 'usda:173424')]));
      expect(Store.i.stockItem('eggs')!.left, 10);
      expect(Store.i.stockChecks.map((e) => e.id), ['m3']);
    });

    test('stock never goes below zero', () async {
      await Store.i.putStock(eggs.copyWith(left: 1));
      await Store.i.putEntry(meal('m4', [twoEggs]).copyWith(stock: () => {'eggs': 2}));
      expect(Store.i.stockItem('eggs')!.left, 0);
      expect(Store.i.entry('m4')!.stock, {'eggs': 1}); // only what was there
      await Store.i.deleteEntry('m4');
      expect(Store.i.stockItem('eggs')!.left, 1);
    });
  });

  test('stock amounts read naturally', () {
    expect(formatStock(8, 'piece'), '8');
    expect(formatStock(450, 'g'), '450 g');
    expect(formatStock(1250, 'g'), '1.3 kg');
    expect(formatStock(500, 'ml'), '500 ml');
  });

  test('shopping is read on the phone, raw and in base units', () {
    final db = loadTestDb();
    final d = readStock('10 eggs, 450g chicken breast, 2 dozen bananas, milk 1 l', db)!;
    expect(d.map((x) => (x.name, x.amount, x.unit)), [
      ('Eggs', 10.0, 'piece'),
      ('Chicken breast', 450.0, 'g'),
      ('Bananas', 24.0, 'piece'),
      ('Milk', 1000.0, 'ml'),
    ]);
    expect(d[0].pieceGrams, 50);
    expect(d[1].raw, isTrue);
    expect(foodState(db.get(d[1].ref)!.name), 'raw');
    expect(readStock('a dozen eggs', db)!.single.amount, 12);
    expect(readStock('some chicken', db), isNull); // no amount, no guess
  });
}
