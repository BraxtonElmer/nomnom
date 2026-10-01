import 'dart:io';

import 'package:nomnom/nutrition/cuisines.dart';
import 'package:nomnom/nutrition/food_db.dart';

/// The real bundled tables, read straight from disk.
FoodDb loadTestDb() => FoodDb.fromRaw(File('assets/data/usda.json').readAsStringSync(), {
  for (final c in cuisines) c.id: File(c.asset).readAsStringSync(),
});
