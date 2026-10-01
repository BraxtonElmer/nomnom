import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: C.p.brightness,
    fontFamily: F.sans,
    scaffoldBackgroundColor: C.paper,
    colorScheme: ColorScheme(
      brightness: C.p.brightness,
      surface: C.paper,
      onSurface: C.ink,
      primary: C.ink,
      onPrimary: C.paper,
      secondary: C.tomato,
      onSecondary: C.onTomato,
      error: C.tomato,
      onError: C.onTomato,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.tomato,
      selectionColor: C.tomatoSoft,
      selectionHandleColor: C.tomato,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: _FadeRise(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: C.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: C.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
  );
}

/// Quick fade + 12px rise. Feels instant without the stock zoom.
class _FadeRise extends PageTransitionsBuilder {
  const _FadeRise();

  @override
  Widget buildTransitions<R>(
    PageRoute<R> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
