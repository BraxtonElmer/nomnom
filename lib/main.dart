import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/inbox.dart';
import 'data/reminders.dart';
import 'data/store.dart';
import 'data/today_widget.dart';
import 'nutrition/food_db.dart';
import 'screens/setup/onboarding.dart';
import 'screens/shell.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.i.init();
  await Store.i.checkKey();
  await Inbox.drain();
  // Food tables parse in the background; the first parse awaits them.
  FoodDb.load();
  runApp(const NomnomApp());
  Reminders.init();
  TodayWidget.start();
}

class NomnomApp extends StatefulWidget {
  const NomnomApp({super.key});

  @override
  State<NomnomApp> createState() => _NomnomAppState();
}

class _NomnomAppState extends State<NomnomApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => setState(() {});

  bool get _dark => switch (Store.i.theme) {
    'dark' => true,
    'light' => false,
    _ => WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final dark = _dark;
        C.p = dark ? Palette.dark : Palette.light;
        final icons = dark ? Brightness.light : Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            systemNavigationBarColor: C.paper,
            systemNavigationBarIconBrightness: icons,
          ),
        );
        // Colours are read at build time, so a new palette remounts the app.
        return MaterialApp(
          key: ValueKey(dark),
          title: 'nomnom',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: AnimatedSwitcher(
            duration: Motion.slow,
            child: Store.i.onboarded
                ? const Shell(key: ValueKey('shell'))
                : const Onboarding(key: ValueKey('onboarding')),
          ),
        );
      },
    );
  }
}
