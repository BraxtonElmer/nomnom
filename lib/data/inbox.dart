import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'store.dart';

/// Replies typed into a reminder notification. The reply arrives in a
/// background isolate that can't safely open the database, so it's appended
/// to a small file; the app moves it into the log queue on its next open.
class Inbox {
  static Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/nomnom_inbox.jsonl');

  static Future<void> add(String text, Meal meal, DateTime at) async {
    final f = await _file();
    await f.writeAsString(
      '${jsonEncode({'x': text, 'm': meal.name, 'at': at.millisecondsSinceEpoch})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Forgets replies not yet read (used when wiping all data).
  static Future<void> clear() async {
    if (kIsWeb) return;
    final f = await _file();
    if (await f.exists()) await f.delete();
  }

  /// Moves replies into the waiting list. Returns how many were waiting.
  static Future<int> drain() async {
    if (kIsWeb) return 0;
    try {
      final f = await _file();
      if (!await f.exists()) return 0;
      // Move it aside first: a reply arriving meanwhile starts a new file
      // instead of being deleted unread.
      final taken = await f.rename('${f.path}.reading');
      final lines = (await taken.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
      var n = 0;
      for (final l in lines) {
        try {
          final j = jsonDecode(l) as Map<String, dynamic>;
          await Store.i.addPending(
            PendingLog(
              id: Store.newId(),
              at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
              meal: Meal.parse(j['m']),
              text: j['x'] as String,
            ),
          );
          n++;
        } catch (e) {
          debugPrint('Skipped an unreadable reply: $e');
        }
      }
      await taken.delete();
      return n;
    } catch (e) {
      debugPrint('Inbox unreadable: $e');
      return 0;
    }
  }
}

/// The reminder's payload: which meal it was for and when.
String reminderPayload(Meal meal, DateTime at) => '${meal.name}|${at.millisecondsSinceEpoch}';

(Meal, DateTime) parseReminderPayload(String? p) {
  final parts = (p ?? '').split('|');
  final at = parts.length > 1 ? int.tryParse(parts[1]) : null;
  return (
    Meal.parse(parts.first),
    at == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(at),
  );
}

/// When a reply to a reminder for [at] counts as eaten: the moment of
/// replying, unless that has run into the next day (a late reply to last
/// night's dinner still belongs to last night).
DateTime replyTime(DateTime at, DateTime now) =>
    dayOf(now) == dayOf(at) && now.isAfter(at) ? now : at;

/// Runs in a background isolate when someone replies from the notification
/// shade without opening the app.
@pragma('vm:entry-point')
Future<void> onReminderReply(NotificationResponse r) async {
  final text = r.input?.trim() ?? '';
  if (r.actionId != 'log' || text.isEmpty) return;
  WidgetsFlutterBinding.ensureInitialized();
  final (meal, at) = parseReminderPayload(r.payload);
  await Inbox.add(text, meal, replyTime(at, DateTime.now()));
  final plugin = FlutterLocalNotificationsPlugin();
  if (r.id != null) await plugin.cancel(id: r.id!);
  await plugin.show(
    id: 900,
    title: 'Saved for ${meal.label.toLowerCase()}',
    body: '“$text” will be logged when you open nomnom.',
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'reply_saved',
        'Saved replies',
        channelDescription: 'Quiet confirmation after replying to a reminder',
        importance: Importance.low,
        icon: 'ic_stat_nomnom',
        timeoutAfter: 8000,
      ),
    ),
  );
}
