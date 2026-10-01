import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'nutrition/food_db.dart';
import 'screens/setup/onboarding.dart';
import 'screens/shell.dart';
import 'theme/theme.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: C.paper,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await Store.i.init();
  // Food tables parse in the background; the first parse awaits them.
  FoodDb.load();
  runApp(const NomnomApp());
}

class NomnomApp extends StatelessWidget {
  const NomnomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'nomnom',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => AnimatedSwitcher(
          duration: Motion.slow,
          child: Store.i.onboarded
              ? const Shell(key: ValueKey('shell'))
              : const Onboarding(key: ValueKey('onboarding')),
        ),
      ),
    );
  }
}
