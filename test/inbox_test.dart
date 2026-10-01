import 'package:flutter_test/flutter_test.dart';
import 'package:nomnom/data/inbox.dart';
import 'package:nomnom/data/models.dart';

void main() {
  test('a reminder remembers which meal and when it was for', () {
    final at = DateTime(2026, 10, 1, 21);
    final (meal, time) = parseReminderPayload(reminderPayload(Meal.dinner, at));
    expect(meal, Meal.dinner);
    expect(time, at);
  });

  test('a missing payload still gives a usable meal and time', () {
    final (meal, time) = parseReminderPayload(null);
    expect(meal, Meal.snack);
    expect(DateTime.now().difference(time).inSeconds, lessThan(5));
  });
}
