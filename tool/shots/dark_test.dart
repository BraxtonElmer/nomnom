import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/screens/log/review_screen.dart';
import 'package:nomnom/screens/progress/progress_screen.dart';
import 'package:nomnom/screens/setup/onboarding.dart';
import 'package:nomnom/screens/shell.dart';
import 'package:nomnom/screens/you/you_screen.dart';
import 'package:nomnom/theme/tokens.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });
  tearDown(() => C.p = Palette.light);

  testWidgets('dark today', (t) => shoot(t, 'dark_today', const Shell(), dark: true));
  testWidgets('dark review', (t) async {
    final e = Store.i.entriesOn(DateTime.now()).firstWhere((e) => e.id == 'l0');
    await shoot(t, 'dark_review', ReviewScreen.edit(entry: e), dark: true);
  });
  testWidgets('dark progress',
      (t) => shoot(t, 'dark_progress', const Scaffold(body: ProgressScreen()), dark: true));
  testWidgets('dark you', (t) => shoot(t, 'dark_you', const Scaffold(body: YouScreen()), dark: true));
  testWidgets('dark welcome', (t) => shoot(t, 'dark_welcome', const Onboarding(), dark: true));
}
