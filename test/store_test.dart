import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  setUpAll(() => Store.i.init(path: Directory.systemTemp.createTempSync('nomnom_store').path));

  const roti = FoodItem(
    name: 'Roti',
    qty: 2,
    unit: 'piece',
    unitGrams: 40,
    per100: Nutrients(kcal: 300, protein: 9.6, carbs: 52, fat: 6),
    source: Source.dish,
    ref: 'in-roti',
  );

  test('entries index by day, streak counts back from today', () async {
    final now = DateTime.now();
    for (var d = 0; d < 3; d++) {
      await Store.i.putEntry(
        Entry(
          id: 'e$d',
          at: now.subtract(Duration(days: d)),
          meal: Meal.lunch,
          title: 'Roti',
          text: '2 rotis',
          items: const [roti],
        ),
      );
    }
    expect(Store.i.totalOn(now).kcal, 240);
    expect(Store.i.streak, 3);
    expect(Store.i.recents().length, 1); // same title collapses
    expect(Store.i.recall('roti')!.ref, 'in-roti'); // remembered for next time
  });

  test('backup round-trips and excludes keys', () async {
    await Store.i.addFavourite(Store.i.entry('e0')!);
    await Store.i.saveProfile(Store.i.profile.copyWith(customKcal: () => 1900));
    final json = Store.i.exportJson();
    expect(json, isNot(contains('gsk_')));

    await Store.i.wipe();
    expect(Store.i.onboarded, isFalse);
    expect(Store.i.totalOn(DateTime.now()).kcal, 0);

    final n = await Store.i.importJson(json);
    expect(n, 3);
    expect(Store.i.onboarded, isTrue);
    expect(Store.i.favourites.single.title, 'Roti');
    expect(Store.i.targets.kcal, 1900);
    expect(() => Store.i.importJson('{"app":"other"}'), throwsFormatException);
  });

  test('logs saved for later persist per day until removed', () async {
    final now = DateTime.now();
    await Store.i.addPending(
      PendingLog(id: 'p1', at: now, meal: Meal.dinner, text: 'chicken curry and rice'),
    );
    expect(Store.i.pendingOn(now).single.text, 'chicken curry and rice');
    expect(Store.i.pendingOn(now.subtract(const Duration(days: 1))), isEmpty);
    await Store.i.removePending('p1');
    expect(Store.i.pending, isEmpty);
  });

  test('copying keeps meal and time of day on the new day', () async {
    final y = DateTime(2026, 9, 30, 8, 40);
    final e = Entry(id: 'y1', at: y, meal: Meal.breakfast, title: 'Poha', text: 'poha',
        items: const [roti]);
    await Store.i.putEntry(e);
    final copies = await Store.i.copyTo([e], DateTime(2026, 10, 1));
    expect(copies.single.id, isNot('y1'));
    expect(copies.single.at, DateTime(2026, 10, 1, 8, 40));
    expect(copies.single.meal, Meal.breakfast);
    expect(Store.i.entriesOn(DateTime(2026, 10, 1)).map((x) => x.title), contains('Poha'));
  });
}
