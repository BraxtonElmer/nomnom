import 'package:flutter/material.dart';

/// One set of Paper colours. Light is cream paper and ink; dark is the same
/// page at night: warm near-black paper, cream ink, a brighter tomato.
class Palette {
  const Palette({
    required this.brightness,
    required this.paper,
    required this.paperDeep,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.lineStrong,
    required this.tomato,
    required this.tomatoSoft,
    required this.onTomato,
    required this.good,
    required this.carbs,
    required this.fat,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;
  final Color paper;
  final Color paperDeep;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color lineStrong;
  final Color tomato;
  final Color tomatoSoft;
  final Color onTomato;
  final Color good;
  final Color carbs;
  final Color fat;
  final Color shadow;
  final Color scrim;

  static const light = Palette(
    brightness: Brightness.light,
    paper: Color(0xFFF4F1EA),
    paperDeep: Color(0xFFEAE5DA),
    card: Color(0xFFFBF9F4),
    ink: Color(0xFF1A1916),
    ink2: Color(0xFF6B675E),
    ink3: Color(0xFF8A857A),
    line: Color(0xFFDDD7CB),
    lineStrong: Color(0xFFC9C2B3),
    tomato: Color(0xFFB8361F),
    tomatoSoft: Color(0xFFF3DED6),
    onTomato: Color(0xFFFFFFFF),
    good: Color(0xFF2F6B3E),
    carbs: Color(0xFFA57A17),
    fat: Color(0xFF4F6B45),
    shadow: Color(0x1A1A1916),
    scrim: Color(0x661A1916),
  );

  static const dark = Palette(
    brightness: Brightness.dark,
    paper: Color(0xFF141311),
    paperDeep: Color(0xFF1E1C19),
    card: Color(0xFF2A2723),
    ink: Color(0xFFEDE8DD),
    ink2: Color(0xFFA8A397),
    ink3: Color(0xFF79746B),
    line: Color(0xFF2E2B27),
    lineStrong: Color(0xFF3E3A34),
    tomato: Color(0xFFE2664C),
    tomatoSoft: Color(0xFF3A221C),
    onTomato: Color(0xFF1A0C08),
    good: Color(0xFF7FC48F),
    carbs: Color(0xFFD5A640),
    fat: Color(0xFF93B383),
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
  );
}

/// The active palette. Read at build time; the app remounts when it changes.
class C {
  static Palette p = Palette.light;
  static bool get isDark => p.brightness == Brightness.dark;

  static Color get paper => p.paper;
  static Color get paperDeep => p.paperDeep;
  static Color get card => p.card;
  static Color get ink => p.ink;
  static Color get ink2 => p.ink2;
  static Color get ink3 => p.ink3;
  static Color get line => p.line;
  static Color get lineStrong => p.lineStrong;
  static Color get tomato => p.tomato;
  static Color get tomatoSoft => p.tomatoSoft;
  static Color get onTomato => p.onTomato;
  static Color get good => p.good;
  static Color get shadow => p.shadow;
  static Color get scrim => p.scrim;

  // Macros
  static Color get protein => p.tomato;
  static Color get carbs => p.carbs;
  static Color get fat => p.fat;
}

class F {
  static const sans = 'Clash';
  static const serif = 'Instrument Serif';
  static const tnum = [FontFeature.tabularFigures()];
}

/// Type scale. Serif carries display and numbers that deserve attention,
/// sans carries everything you read quickly.
class T {
  static TextStyle get display =>
      TextStyle(fontFamily: F.serif, fontSize: 44, height: 1.0, color: C.ink, letterSpacing: -0.4);
  static TextStyle get title =>
      TextStyle(fontFamily: F.serif, fontSize: 30, height: 1.05, color: C.ink);
  static TextStyle get heading =>
      TextStyle(fontFamily: F.serif, fontSize: 24, height: 1.1, color: C.ink);
  static TextStyle get brand => TextStyle(
    fontFamily: F.serif,
    fontSize: 30,
    fontStyle: FontStyle.italic,
    height: 1,
    color: C.ink,
  );

  static TextStyle get body =>
      TextStyle(fontFamily: F.sans, fontSize: 15, height: 1.35, color: C.ink, fontFeatures: F.tnum);
  static TextStyle get bodyStrong => TextStyle(
    fontFamily: F.sans,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: C.ink,
    fontFeatures: F.tnum,
  );
  static TextStyle get small => TextStyle(
    fontFamily: F.sans,
    fontSize: 13,
    height: 1.35,
    color: C.ink2,
    fontFeatures: F.tnum,
  );
  static TextStyle get caps => TextStyle(
    fontFamily: F.sans,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.1,
    color: C.ink2,
    fontWeight: FontWeight.w500,
  );
  static TextStyle get button =>
      TextStyle(fontFamily: F.sans, fontSize: 16, fontWeight: FontWeight.w500, color: C.paper);
}

class S {
  static const gutter = 24.0;
  static const radius = 22.0;
}

class Motion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
}
