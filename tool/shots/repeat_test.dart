import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/screens/shell.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
    await Store.i.removePending('p1'); // leave tonight's dinner empty
  });

  testWidgets('same as yesterday', (tester) async {
    await shoot(tester, 'repeat', const Shell());
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/repeat.png'));
  });
}
