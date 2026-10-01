import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SafeArea(child: Center(child: Text('Progress', style: T.title)));
}
