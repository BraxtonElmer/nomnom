import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'inbox.dart';
import 'log_queue.dart';
import 'models.dart';
import 'store.dart';

/// Nudges for meals you haven't logged. A repeating daily alarm can't skip a
/// day you've already logged, so instead one-off reminders are laid out for
/// the coming week and re-laid every time the log changes.
class Reminders {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static Timer? _debounce;

  static const meals = [Meal.breakfast, Meal.lunch, Meal.dinner];

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        onDidReceiveNotificationResponse: _foreground,
        onDidReceiveBackgroundNotificationResponse: onReminderReply,
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_nomnom'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
      Store.i.addListener(_changed);
      await reschedule();
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// Asks for notification permission, then turns reminders on.
  static Future<bool> enable() async {
    await init();
    if (!_ready) return false;
    final granted = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission(),
      _ =>
        await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true),
    };
    if (granted != true) return false;
    await Store.i.setReminders(on: true);
    return true;
  }

  /// A reply handled while the app is running: same path as the background
  /// one, then read straight away.
  static Future<void> _foreground(NotificationResponse r) async {
    final text = r.input?.trim() ?? '';
    if (r.actionId != 'log' || text.isEmpty) return;
    final (meal, at) = parseReminderPayload(r.payload);
    await Inbox.add(text, meal, replyTime(at, DateTime.now()));
    await Inbox.drain();
    await LogQueue.process();
  }

  static void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), reschedule);
  }

  static Future<void> reschedule() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!Store.i.remindersOn) return;
      final now = tz.TZDateTime.now(tz.local);
      for (var d = 0; d < 7; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        final logged = {for (final e in Store.i.entriesOn(day)) e.meal};
        for (final meal in meals) {
          if (logged.contains(meal)) continue;
          final minutes = Store.i.reminderAt(meal);
          final at = tz.TZDateTime(
            tz.local,
            day.year,
            day.month,
            day.day,
            minutes ~/ 60,
            minutes % 60,
          );
          if (at.isBefore(now)) continue;
          await _plugin.zonedSchedule(
            id: d * 10 + meal.index,
            title: '${meal.label} not logged yet',
            body: _nudges[(d + meal.index) % _nudges.length],
            scheduledDate: at,
            payload: reminderPayload(meal, at),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'meal_reminders',
                'Meal reminders',
                channelDescription: 'A nudge when a meal hasn’t been logged',
                importance: Importance.defaultImportance,
                actions: [
                  AndroidNotificationAction(
                    'log',
                    'Log it',
                    inputs: [AndroidNotificationActionInput(label: 'What did you eat?')],
                  ),
                ],
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }

  static const _nudges = [
    'Type what you had. One line is enough.',
    'Quick one: what was on the plate?',
    'Log it while you remember.',
  ];
}
