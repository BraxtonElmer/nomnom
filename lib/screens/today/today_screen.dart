import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: Center(child: Text('Today', style: T.title)));
}
