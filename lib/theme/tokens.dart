import 'package:flutter/material.dart';

/// Paper palette: cream ground, ink type, one tomato accent.
class C {
  static const paper = Color(0xFFF4F1EA);
  static const paperDeep = Color(0xFFEAE5DA);
  static const card = Color(0xFFFBF9F4);
  static const ink = Color(0xFF1A1916);
  static const ink2 = Color(0xFF6B675E);
  static const ink3 = Color(0xFF8A857A);
  static const line = Color(0xFFDDD7CB);
  static const lineStrong = Color(0xFFC9C2B3);
  static const tomato = Color(0xFFB8361F);
  static const tomatoSoft = Color(0xFFF3DED6);
  static const good = Color(0xFF2F6B3E);

  // Macros
  static const protein = tomato;
  static const carbs = Color(0xFFA57A17);
  static const fat = Color(0xFF4F6B45);
}

class F {
  static const sans = 'Clash';
  static const serif = 'Instrument Serif';
  static const tnum = [FontFeature.tabularFigures()];
}

/// Type scale. Serif carries display and numbers that deserve attention,
/// sans carries everything you read quickly.
class T {
  static const display = TextStyle(
      fontFamily: F.serif, fontSize: 44, height: 1.0, color: C.ink, letterSpacing: -0.4);
  static const title = TextStyle(
      fontFamily: F.serif, fontSize: 30, height: 1.05, color: C.ink);
  static const heading = TextStyle(
      fontFamily: F.serif, fontSize: 24, height: 1.1, color: C.ink);
  static const brand = TextStyle(
      fontFamily: F.serif, fontSize: 30, fontStyle: FontStyle.italic, height: 1, color: C.ink);

  static const body = TextStyle(
      fontFamily: F.sans, fontSize: 15, height: 1.35, color: C.ink, fontFeatures: F.tnum);
  static const bodyStrong = TextStyle(
      fontFamily: F.sans, fontSize: 15, height: 1.35, fontWeight: FontWeight.w500,
      color: C.ink, fontFeatures: F.tnum);
  static const small = TextStyle(
      fontFamily: F.sans, fontSize: 13, height: 1.35, color: C.ink2, fontFeatures: F.tnum);
  static const caps = TextStyle(
      fontFamily: F.sans, fontSize: 11, height: 1.2, letterSpacing: 1.1,
      color: C.ink2, fontWeight: FontWeight.w500);
  static const button = TextStyle(
      fontFamily: F.sans, fontSize: 16, fontWeight: FontWeight.w500, color: C.paper);
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
