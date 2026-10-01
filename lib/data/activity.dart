import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import 'models.dart';
import 'store.dart';

class DayActivity {
  const DayActivity({this.steps = 0, this.activeKcal = 0});

  final int steps;
  final double activeKcal;
}

/// Steps, active calories and sleep from Android Health Connect. Read only,
/// cached per day in memory and refreshed when Today comes into view.
class Activity extends ChangeNotifier {
  Activity._();
  static final Activity i = Activity._();

  final _health = Health();
  final Map<DateTime, DayActivity> _days = {};
  int? _sleepMinutes;
  bool _configured = false;
  DateTime? _lastRefresh;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
  ];

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get connected => supported && Store.i.healthConnected;

  DayActivity on(DateTime day) => _days[dayOf(day)] ?? const DayActivity();

  /// Minutes asleep last night, if Health Connect has it.
  int? get sleepMinutes => _sleepMinutes;

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Health Connect installed and up to date on this phone.
  Future<bool> available() async {
    if (!supported) return false;
    try {
      return await _health.getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstall() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {}
  }

  Future<bool> connect() async {
    if (!supported) return false;
    try {
      await _configure();
      final ok = await _health.requestAuthorization(
        _types,
        permissions: _types.map((_) => HealthDataAccess.READ).toList(),
      );
      await Store.i.setHealth(connected: ok);
      if (ok) await refresh(force: true);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    _days.clear();
    _sleepMinutes = null;
    await Store.i.setHealth(connected: false);
    try {
      await _health.revokePermissions();
    } catch (_) {}
    notifyListeners();
  }

  /// Pulls the last [days] days. Throttled to once a minute unless forced.
  Future<void> refresh({int days = 7, bool force = false}) async {
    if (!connected) return;
    final now = DateTime.now();
    if (!force && _lastRefresh != null && now.difference(_lastRefresh!).inSeconds < 60) return;
    _lastRefresh = now;
    try {
      await _configure();
      final today = dayOf(now);
      for (var d = 0; d < days; d++) {
        final start = today.subtract(Duration(days: d));
        final end = d == 0 ? now : start.add(const Duration(days: 1));
        _days[start] = await _between(start, end);
      }
      _sleepMinutes = await _sleep(today, now);
      notifyListeners();
    } catch (e) {
      debugPrint('Health Connect read failed: $e');
    }
  }

  Future<DayActivity> _between(DateTime start, DateTime end) async {
    var steps = 0;
    var kcal = 0.0;
    try {
      steps = await _health.getTotalStepsInInterval(start, end) ?? 0;
    } catch (_) {}
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      );
      for (final p in _health.removeDuplicates(points)) {
        final v = p.value;
        if (v is NumericHealthValue) kcal += v.numericValue.toDouble();
      }
    } catch (_) {}
    return DayActivity(steps: steps, activeKcal: kcal);
  }

  /// Sleep sessions that ended this morning: 6 pm yesterday to noon today.
  Future<int?> _sleep(DateTime today, DateTime now) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.SLEEP_ASLEEP],
        startTime: today.subtract(const Duration(hours: 6)),
        endTime: now.isBefore(today.add(const Duration(hours: 12)))
            ? now
            : today.add(const Duration(hours: 12)),
      );
      if (points.isEmpty) return null;
      return _health
          .removeDuplicates(points)
          .fold<int>(0, (s, p) => s + p.dateTo.difference(p.dateFrom).inMinutes);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  void seed(Map<DateTime, DayActivity> days, {int? sleep}) {
    _days
      ..clear()
      ..addAll({for (final e in days.entries) dayOf(e.key): e.value});
    _sleepMinutes = sleep;
    notifyListeners();
  }
}
