// Renders the app icon and splash mark into assets/icon/ with the real
// fonts. Run: flutter test tool/brand --update-goldens
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/theme/tokens.dart';

/// Ink ring three-quarters closed, a tomato dot where it ends, and an
/// italic serif "n" inside: the Today ring, as a mark.
class Mark extends StatelessWidget {
  const Mark({super.key, required this.size, this.background});

  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    color: background ?? Colors.transparent,
    alignment: Alignment.center,
    child: SizedBox(
      width: size * 0.62,
      height: size * 0.62,
      child: CustomPaint(
        painter: _RingPainter(),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.05),
            child: Text(
              'n',
              style: TextStyle(
                fontFamily: F.serif,
                fontStyle: FontStyle.italic,
                fontSize: size * 0.42,
                height: 1,
                color: C.ink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.075;
    final r = (Offset.zero & size).deflate(stroke / 2);
    const sweep = math.pi * 2 * 0.74;
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = C.line,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = C.ink,
    );
    final end = -math.pi / 2 + sweep;
    final c = r.center + Offset(math.cos(end), math.sin(end)) * (r.width / 2);
    canvas.drawCircle(c, stroke * 0.95, Paint()..color = C.tomato);
  }

  @override
  bool shouldRepaint(_RingPainter old) => false;
}

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _font(F.serif, ['assets/fonts/InstrumentSerif-Italic.ttf']);
  });

  Future<void> render(WidgetTester t, String name, Widget w) async {
    t.view.physicalSize = const Size(1024, 1024);
    t.view.devicePixelRatio = 1;
    await t.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: w));
    await expectLater(find.byWidget(w), matchesGoldenFile('../../assets/icon/$name.png'));
  }

  testWidgets('icon', (t) => render(t, 'icon', const Mark(size: 1024, background: C.paper)));
  // Adaptive foreground: Android crops to a circle inside the middle 66%.
  testWidgets(
    'foreground',
    (t) => render(
      t,
      'foreground',
      const Padding(padding: EdgeInsets.all(170), child: Mark(size: 684)),
    ),
  );
  testWidgets('splash', (t) => render(t, 'splash', const Mark(size: 1024)));
}
