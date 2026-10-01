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

  /// Moves replies into the waiting list. Returns how many were waiting.
  static Future<int> drain() async {
    if (kIsWeb) return 0;
    try {
      final f = await _file();
      if (!await f.exists()) return 0;
      final lines = (await f.readAsLines()).where((l) => l.trim().isNotEmpty).toList();
      await f.delete();
      for (final l in lines) {
        final j = jsonDecode(l) as Map<String, dynamic>;
        await Store.i.addPending(
          PendingLog(
            id: Store.newId(),
            at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
            meal: Meal.parse(j['m']),
            text: j['x'] as String,
          ),
        );
      }
      return lines.length;
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

/// Runs in a background isolate when someone replies from the notification
/// shade without opening the app.
@pragma('vm:entry-point')
Future<void> onReminderReply(NotificationResponse r) async {
  final text = r.input?.trim() ?? '';
  if (r.actionId != 'log' || text.isEmpty) return;
  WidgetsFlutterBinding.ensureInitialized();
  final (meal, at) = parseReminderPayload(r.payload);
  // Log it at the moment of replying, unless that's already past the meal.
  await Inbox.add(text, meal, DateTime.now().isBefore(at) ? at : DateTime.now());
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
