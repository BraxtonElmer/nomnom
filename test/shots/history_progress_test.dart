import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/screens/history/history_screen.dart';
import 'package:nomnom/screens/progress/progress_screen.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
  });

  testWidgets('history', (tester) async {
    await shoot(tester, 'history', const Scaffold(body: HistoryScreen()));
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (yesterday.month == DateTime.now().month) {
      await tester.tap(find.text('${yesterday.day}'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../../build/shots/history_day.png'),
      );
    }
  });

  testWidgets('progress', (tester) async {
    await shoot(tester, 'progress', const Scaffold(body: ProgressScreen()));
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../build/shots/progress_2.png'),
    );
  });
}
