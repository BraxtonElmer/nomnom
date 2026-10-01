// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/activity.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/theme/theme.dart';

/// Renders screens to build/shots/*.png at phone size with the real fonts.
/// Run: flutter test tool/shots --update-goldens
Future<void> setUpShots() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  Future<void> font(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await font('Clash', [
    for (final w in ['Light', 'Regular', 'Medium', 'Semibold', 'Bold'])
      'assets/fonts/ClashGrotesk-$w.ttf',
  ]);
  await font('Instrument Serif', [
    'assets/fonts/InstrumentSerif-Regular.ttf',
    'assets/fonts/InstrumentSerif-Italic.ttf',
  ]);
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  await font('MaterialIcons', [
    '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);

  final dir = Directory.systemTemp.createTempSync('nomnom_shots');
  await Store.i.init(path: dir.path);
  FoodDb.use(
    FoodDb.fromRaw(
      File('assets/data/usda.json').readAsStringSync(),
      File('assets/data/dishes_in.json').readAsStringSync(),
    ),
  );
}

Future<void> shoot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Future<void> Function(WidgetTester)? act,
}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(
    MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: screen),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  if (act != null) await act(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/$name.png'));
}

FoodItem dbItem(String id, String name, double qty, String unit, double unitGrams) {
  final f = FoodDb.i.get(id)!;
  return FoodItem(
    name: name,
    qty: qty,
    unit: unit,
    unitGrams: unitGrams,
    per100: f.per100,
    source: f.source,
    ref: f.id,
    refName: f.name,
  );
}

/// A believable few days of logging.
Future<void> seed() async {
  final s = Store.i;
  await s.saveProfile(
    const Profile(
      country: 'IN',
      sex: Sex.male,
      age: 27,
      heightCm: 176,
      weightKg: 74,
      activity: 1.55,
      goal: Goal.lose,
      paceKg: 0.5,
    ),
  );
  await s.finishOnboarding();
  final today = dayOf(DateTime.now());
  DateTime at(int daysAgo, int h, int m) =>
      today.subtract(Duration(days: daysAgo)).add(Duration(hours: h, minutes: m));

  final oats = [
    dbItem('in-masala-oats', 'Masala oats', 1, 'bowl', 250),
    dbItem('usda:171890', 'Black coffee', 240, 'ml', 1),
  ];
  final lunch = [
    dbItem('usda:171477', 'Grilled chicken breast', 120, 'g', 1),
    dbItem('in-roti', 'Roti', 2, 'piece', 40),
    dbItem('in-dal-tadka', 'Dal tadka', 1, 'bowl', 200),
  ];
  final snack = [
    dbItem('usda:173944', 'Banana', 1, 'piece', 118),
    dbItem('usda:170567', 'Almonds', 20, 'g', 1),
  ];
  for (var d = 0; d < 9; d++) {
    if (d == 4) continue;
    await s.putEntry(
      Entry(
        id: 'b$d',
        at: at(d, 8, 40),
        meal: Meal.breakfast,
        title: 'Masala oats, black coffee',
        text: 'masala oats and black coffee',
        items: oats,
      ),
    );
    await s.putEntry(
      Entry(
        id: 'l$d',
        at: at(d, 13, 15),
        meal: Meal.lunch,
        title: 'Grilled chicken, 2 rotis, dal',
        text: '120g grilled chicken, 2 rotis and a bowl of dal',
        items: lunch,
      ),
    );
    await s.putEntry(
      Entry(
        id: 's$d',
        at: at(d, 17, 5),
        meal: Meal.snack,
        title: 'Banana, handful of almonds',
        text: 'banana and a handful of almonds',
        items: snack,
      ),
    );
    if (d > 0) {
      await s.putEntry(
        Entry(
          id: 'd$d',
          at: at(d, 20, 30),
          meal: Meal.dinner,
          title: 'Paneer butter masala, 2 roti',
          text: '',
          items: [
            dbItem('in-paneer-butter-masala', 'Paneer butter masala', 1, 'katori', 150),
            dbItem('in-roti', 'Roti', 2, 'piece', 40),
          ],
        ),
      );
    }
  }
  await s.setHealth(connected: true, eatBack: true);
  await s.setReminders(on: true);
  await s.addPending(
    PendingLog(id: 'p1', at: at(0, 20, 10), meal: Meal.dinner, text: 'chicken curry with 2 rotis'),
  );
  Activity.i.seed({
    for (var d = 0; d < 7; d++)
      today.subtract(Duration(days: d)): DayActivity(
        steps: [6418, 9120, 7340, 4210, 11030, 8450, 7790][d],
        activeKcal: [212, 380, 290, 140, 460, 330, 300][d].toDouble(),
      ),
  }, sleep: 437);
  for (var d = 30; d >= 0; d -= 3) {
    await s.logWeight(today.subtract(Duration(days: d)), 76.2 - (30 - d) * 0.07 + (d % 2) * 0.2);
  }
}
