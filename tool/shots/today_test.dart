import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/screens/log/review_screen.dart';
import 'package:nomnom/screens/shell.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });

  testWidgets('today', (tester) async {
    await shoot(tester, 'today', const Shell());
    await tester.tap(find.text('What did you eat?'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/shots/today_quick.png'),
    );
  });

  testWidgets('day details', (tester) async {
    await shoot(tester, 'today_details', const Shell());
    await tester.tap(find.text('All nutrients'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/shots/today_details.png'),
    );
  });

  testWidgets('review', (tester) async {
    final e = Store.i.entriesOn(DateTime.now()).firstWhere((e) => e.id == 'l0');
    await shoot(tester, 'review', ReviewScreen.edit(entry: e));
    await tester.tap(find.text('Greek salad'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/shots/item_sheet.png'),
    );
  });
}
