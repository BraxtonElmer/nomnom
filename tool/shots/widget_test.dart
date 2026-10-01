import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/today_widget.dart';
import 'package:nomnom/theme/tokens.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });
  tearDown(() => C.p = Palette.light);

  for (final dark in [false, true]) {
    testWidgets('widget card ${dark ? 'dark' : 'light'}', (t) async {
      await shoot(
        t,
        'widget_${dark ? 'dark' : 'light'}',
        Scaffold(backgroundColor: const Color(0xFF7A8B99), body: const Center(child: TodayCard())),
        dark: dark,
      );
    });
  }
}
