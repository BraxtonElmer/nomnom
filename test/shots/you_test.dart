import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/screens/you/you_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });

  testWidgets('you', (tester) async {
    await shoot(tester, 'you', const Scaffold(body: YouScreen()));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/you_2.png'));
  });
}
