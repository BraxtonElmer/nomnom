import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/screens/setup/onboarding.dart';

import 'shot.dart';

void main() {
  setUpAll(setUpShots);

  testWidgets('onboarding', (tester) async {
    await shoot(tester, 'onboarding_0_welcome', const Onboarding());
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/onboarding_1_about.png'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/onboarding_2_goal.png'));
    await tester.tap(find.text('Set my own'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/onboarding_2b_custom.png'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/shots/onboarding_3_ai.png'));
  });
}
