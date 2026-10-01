import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'pantry.dart';
import 'reminders.dart';
import 'store.dart';

/// Pantry notifications: when something runs low or out as it's logged, and
/// the morning before a use-by date.
class StockAlerts {
  static Timer? _debounce;
  static bool _started = false;

  /// Ids 5000 and up; meal reminders use 0–69.
  static const _base = 5000;
  static const _now = 4999;

  static void start() {
    if (_started || !Reminders.supported) return;
    _started = true;
    Store.onStockChanged = _changed;
    Store.i.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), _scheduleUseBy);
    });
    _scheduleUseBy();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pantry',
      'Pantry',
      channelDescription: 'When food at home runs low, runs out or is near its use-by date',
      importance: Importance.defaultImportance,
      icon: 'ic_stat_nomnom',
    ),
    iOS: DarwinNotificationDetails(),
  );

  static void _changed(StockItem before, StockItem after) {
    if (!Store.i.stockAlerts || after.left >= before.left) return;
    final String title;
    if (after.isOut && !before.isOut) {
      title = 'Out of ${after.name.toLowerCase()}';
    } else if (after.isLow && !before.isLow) {
      title = '${after.name} running low';
    } else {
      return;
    }
    final body = after.isOut
        ? 'The last of it was just logged. Restock it in Pantry when you buy more.'
        : '${after.amount()} left of ${after.amount(after.full)}.';
    _show(_now, title, body);
  }

  static Future<void> _show(int id, String title, String body) async {
    if (!Reminders.ready) return;
    try {
      await Reminders.plugin.show(id: id, title: title, body: body, notificationDetails: _details);
    } catch (e) {
      debugPrint('Pantry alert not shown: $e');
    }
  }

  static Future<void> _scheduleUseBy() async {
    if (!Reminders.ready) return;
    try {
      for (var i = 0; i < 100; i++) {
        await Reminders.plugin.cancel(id: _base + i);
      }
      if (!Store.i.stockAlerts) return;
      final now = tz.TZDateTime.now(tz.local);
      var i = 0;
      for (final s in Store.i.stock) {
        final by = s.useBy;
        if (by == null || s.isOut || i >= 100) continue;
        // 9 in the morning, the chosen number of days before; or the day
        // itself if that's already past.
        final days = Store.i.useByDays;
        var at = tz.TZDateTime(tz.local, by.year, by.month, by.day - days, 9);
        if (at.isBefore(now)) at = tz.TZDateTime(tz.local, by.year, by.month, by.day, 9);
        if (at.isBefore(now)) continue;
        final left = daysBetween(at, by);
        await Reminders.plugin.zonedSchedule(
          id: _base + i++,
          title:
              '${s.name}: use ${switch (left) {
                0 => 'today',
                1 => 'by tomorrow',
                _ => 'within $left days',
              }}',
          body: '${s.amount()} left. Worth planning a meal around it.',
          scheduledDate: at,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          notificationDetails: _details,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule use-by alerts: $e');
    }
  }
}
