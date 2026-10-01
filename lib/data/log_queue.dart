import '../ai/client.dart';
import '../ai/meal_parser.dart';
import 'models.dart';
import 'store.dart';

/// Reads logs saved while the AI was unreachable. Runs when the app opens
/// or comes back to the foreground; stops at the first failure that is
/// worth retrying later.
class LogQueue {
  static bool _busy = false;

  /// Returns how many waiting logs were turned into entries.
  static Future<int> process() async {
    if (_busy || Store.i.pending.isEmpty) return 0;
    _busy = true;
    var done = 0;
    try {
      MealParser? parser;
      for (final p in Store.i.pending) {
        try {
          final meal =
              await MealParser.readLocally(p.text) ??
              await (parser ??= await MealParser.fromSettings()).parse(p.text);
          await Store.i.putEntry(
            Entry(
              id: Store.newId(),
              at: p.at,
              meal: p.meal,
              title: meal.title,
              text: p.text,
              items: [for (final i in meal.items) i.item],
            ),
          );
          await Store.i.removePending(p.id);
          done++;
        } on AiException catch (e) {
          if (e.later) break;
          // Not food, or unreadable: leave it for the user to open and fix.
        }
      }
    } on AiException {
      // No model connected yet.
    } finally {
      _busy = false;
    }
    return done;
  }
}
