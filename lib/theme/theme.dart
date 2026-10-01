import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: F.sans,
    scaffoldBackgroundColor: C.paper,
    colorScheme: const ColorScheme.light(
      surface: C.paper,
      primary: C.ink,
      onPrimary: C.paper,
      secondary: C.tomato,
      error: C.tomato,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.tomato,
      selectionColor: C.tomatoSoft,
      selectionHandleColor: C.tomato,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _FadeRise(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.paper,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
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
  Widget buildTransitions<R>(PageRoute<R> route, BuildContext context,
      Animation<double> animation, Animation<double> secondary, Widget child) {
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
