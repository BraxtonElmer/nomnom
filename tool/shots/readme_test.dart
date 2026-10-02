import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/theme/tokens.dart';

import 'shot.dart';

/// The README's banner and screenshot strip, drawn from the screen shots.
/// Run after the other shots: flutter test tool/shots --update-goldens
void main() {
  setUpAll(setUpShots);

  Future<ui.Image> load(WidgetTester t, String path) async => (await t.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }))!;

  Future<void> render(WidgetTester t, Size size, Widget child, String file) async {
    C.p = Palette.light;
    t.view.physicalSize = size * 2;
    t.view.devicePixelRatio = 2;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: DefaultTextStyle(style: T.body, child: child),
        ),
      ),
    );
    await t.pumpAndSettle();
    await expectLater(find.byType(Directionality).first, matchesGoldenFile('../../docs/$file'));
  }

  Widget phone(ui.Image img) => Container(
    width: 390,
    height: 844,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(36),
      border: Border.all(color: const Color(0xFFC9C2B3), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x221A1916), blurRadius: 30, offset: Offset(0, 14))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: RawImage(image: img, width: 390, height: 844, fit: BoxFit.fill),
    ),
  );

  testWidgets('screenshot strip', (t) async {
    final shots = [
      for (final n in ['today', 'review', 'progress', 'pantry'])
        await load(t, 'build/shots/$n.png'),
    ];
    await render(
      t,
      const Size(1840, 984),
      Container(
        color: const Color(0xFFEAE5DA),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, s) in shots.indexed) ...[
              if (i > 0) const SizedBox(width: 44),
              phone(s),
            ],
          ],
        ),
      ),
      'screenshot.png',
    );
  });

  testWidgets('banner', (t) async {
    final today = await load(t, 'build/shots/today.png');
    final icon = await load(t, 'assets/icon/icon.png');
    const ink = Color(0xFF1A1916);
    const ink2 = Color(0xFF6B675E);
    await render(
      t,
      const Size(1280, 420),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F1EA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDD7CB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: 72,
              top: 70,
              width: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: RawImage(image: icon, width: 56, height: 56),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'nomnom',
                        style: TextStyle(
                          fontFamily: F.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 60,
                          height: 1,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Type what you ate.\nGet the macros.',
                    style: TextStyle(fontFamily: F.serif, fontSize: 46, height: 1.05, color: ink),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Numbers from real food tables, not guesses.\nFree, no account, no paywall.',
                    style: TextStyle(fontFamily: F.sans, fontSize: 19, height: 1.45, color: ink2),
                  ),
                ],
              ),
            ),
            // The top of the Today screen, as a phone peeking up from below.
            Positioned(
              right: 90,
              top: 52,
              child: Transform.rotate(
                angle: -0.035,
                child: Container(
                  width: 430,
                  height: 430,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: const Color(0xFFC9C2B3), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x261A1916), blurRadius: 34, offset: Offset(0, 16)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(33),
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: RawImage(image: today, width: 430, height: 430 * 844 / 390),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      'banner.png',
    );
  });
}
