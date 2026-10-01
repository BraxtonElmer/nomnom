import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/models.dart';
import 'package:nomnom/data/store.dart';
import 'package:nomnom/screens/shell.dart';

import 'shot.dart';

void main() {
  setUpAll(() async {
    await setUpShots();
    await seed();
    // Three more weeks of full days at ~1,900 while the trend barely moves.
    final today = dayOf(DateTime.now());
    for (var d = 9; d < 27; d++) {
      final day = today.subtract(Duration(days: d));
      await Store.i.putEntry(Entry(
        id: 'x$d', at: day.add(const Duration(hours: 13)), meal: Meal.lunch,
        title: 'Thali', text: '', items: [dbItem('in-chicken-biryani', 'Biryani', 3.5, 'plate', 300)],
      ));
    }
  });

  testWidgets('check-in card', (t) async {
    expect(Store.i.checkIn, isNotNull);
    await shoot(t, 'check_in', const Shell());
  });
}
