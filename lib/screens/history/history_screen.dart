import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: Center(child: Text('History', style: T.title)));
}
