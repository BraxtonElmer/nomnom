import 'package:flutter/material.dart';

import 'theme/theme.dart';
import 'theme/tokens.dart';

void main() {
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
      home: const Scaffold(body: Center(child: Text('nomnom', style: T.brand))),
    );
  }
}
