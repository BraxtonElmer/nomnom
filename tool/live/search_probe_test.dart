// ignore_for_file: avoid_print
// Prints food search candidates for queries: Q='whole milk|poha' flutter test tool/live/search_probe_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../test/support/db.dart';

void main() {
  test('probe', () {
    final db = loadTestDb();
    for (final q in (Platform.environment['Q'] ?? 'whole milk').split('|')) {
      print('== $q');
      for (final f in db.search(q, country: Platform.environment['COUNTRY'] ?? 'IN')) {
        print('   ${f.id}  ${f.name}');
      }
    }
  });
}
