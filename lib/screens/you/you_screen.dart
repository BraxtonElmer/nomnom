import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context) => const SafeArea(
    child: Center(child: Text('You', style: T.title)),
  );
}
