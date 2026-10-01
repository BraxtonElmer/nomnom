import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/nutrition/food_db.dart';
import 'package:nomnom/theme/theme.dart';

/// Renders screens to build/shots/*.png at phone size with the real fonts.
/// Run: flutter test test/shots --update-goldens
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
      'assets/fonts/ClashGrotesk-$w.ttf'
  ]);
  await font('Instrument Serif',
      ['assets/fonts/InstrumentSerif-Regular.ttf', 'assets/fonts/InstrumentSerif-Italic.ttf']);
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  await font('MaterialIcons', ['$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);

  final dir = Directory.systemTemp.createTempSync('nomnom_shots');
  await Store.i.init(path: dir.path);
  FoodDb.use(FoodDb.fromRaw(
    File('assets/data/usda.json').readAsStringSync(),
    File('assets/data/dishes_in.json').readAsStringSync(),
  ));
}

Future<void> shoot(WidgetTester tester, String name, Widget screen,
    {Future<void> Function(WidgetTester)? act}) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: screen,
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5));
  if (act != null) await act(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/$name.png'));
}
