import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/screens/log/review_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });

  testWidgets('local review', (tester) async {
    await shoot(tester, 'local_review',
        ReviewScreen.parse(text: '2 boiled eggs, 2 slices of toast and a banana', at: DateTime.now()),
        act: (t) async {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
      await t.pumpAndSettle();
    });
    await tester.tap(find.text('Banana'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/local_item.png'));
  });
}
