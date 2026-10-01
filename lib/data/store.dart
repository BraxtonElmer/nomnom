import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../nutrition/check_in.dart';
import '../nutrition/targets.dart';
import 'inbox.dart';
import 'keys.dart';
import 'models.dart';

/// Everything the app knows, held in memory and written through to Hive.
/// Reads are synchronous, which is what keeps every screen instant.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  late Box<String> _settings;
  late Box<String> _entries;
  late Box<String> _favs;
  late Box<String> _weights;
  late Box<String> _memory;
  late Box<String> _pending;

  Profile profile = const Profile();
  AiConfig ai = const AiConfig();
  bool onboarded = false;
  bool healthConnected = false;

  /// Add active calories burned to the day's budget.
  bool eatBack = false;

  bool remindersOn = false;

  /// Use AI estimates for everything instead of the food tables.
  bool aiOnly = false;

  /// 'system', 'light' or 'dark'.
  String theme = 'system';

  DateTime? _checkInQuietUntil;

  /// AI is configured but its key isn't on this phone (e.g. after a restore).
  bool keyMissing = false;
  final Map<Meal, int> _reminderMinutes = {};

  static const _defaultReminders = {
    Meal.breakfast: 10 * 60 + 30,
    Meal.lunch: 14 * 60 + 30,
    Meal.dinner: 21 * 60,
  };

  /// Minutes after midnight to nudge for [meal].
  int reminderAt(Meal meal) => _reminderMinutes[meal] ?? _defaultReminders[meal] ?? 12 * 60;

  final List<Entry> _all = [];
  final Map<DateTime, List<Entry>> _byDay = {};
  final List<Favourite> _favList = [];
  final List<WeightEntry> _weightList = [];
  final List<PendingLog> _pendingList = [];

  Future<void> init({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('nomnom');
    }
    _settings = await Hive.openBox<String>('settings');
    _entries = await Hive.openBox<String>('entries');
    _favs = await Hive.openBox<String>('favourites');
    _weights = await Hive.openBox<String>('weights');
    _memory = await Hive.openBox<String>('memory');
    _pending = await Hive.openBox<String>('pending');
    _load();
  }

  void _load() {
    final p = _settings.get('profile');
    final a = _settings.get('ai');
    profile = p == null ? const Profile() : Profile.fromJson(_map(p));
    ai = a == null ? const AiConfig() : AiConfig.fromJson(_map(a));
    onboarded = _settings.get('onboarded') == 'true';
    healthConnected = _settings.get('health') == 'true';
    eatBack = _settings.get('eatBack') == 'true';
    remindersOn = _settings.get('reminders') == 'true';
    aiOnly = _settings.get('aiOnly') == 'true';
    theme = _settings.get('theme') ?? 'system';
    final quiet = int.tryParse(_settings.get('checkInQuiet') ?? '');
    _checkInQuietUntil = quiet == null ? null : DateTime.fromMillisecondsSinceEpoch(quiet);
    _reminderMinutes.clear();
    for (final m in Meal.values) {
      final v = int.tryParse(_settings.get('remind_${m.name}') ?? '');
      if (v != null) _reminderMinutes[m] = v;
    }

    _all
      ..clear()
      ..addAll(_entries.values.map((v) => Entry.fromJson(_map(v))));
    _reindex();
    _pendingList
      ..clear()
      ..addAll(_pending.values.map((v) => PendingLog.fromJson(_map(v))))
      ..sort((a, b) => a.at.compareTo(b.at));
    _favList
      ..clear()
      ..addAll(_favs.values.map((v) => Favourite.fromJson(_map(v))));
    _weightList
      ..clear()
      ..addAll(_weights.values.map((v) => WeightEntry.fromJson(_map(v))))
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  static Map<String, dynamic> _map(String s) => Map<String, dynamic>.from(jsonDecode(s));

  void _reindex() {
    _all.sort((a, b) => a.at.compareTo(b.at));
    _byDay.clear();
    for (final e in _all) {
      _byDay.putIfAbsent(dayOf(e.at), () => []).add(e);
    }
  }

  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      Random().nextInt(1 << 20).toRadixString(36);

  // Profile & settings

  Targets get targets => Targets.of(profile);

  Future<void> saveProfile(Profile p) async {
    profile = p;
    notifyListeners();
    await _settings.put('profile', jsonEncode(p.toJson()));
  }

  Future<void> checkKey() async {
    keyMissing =
        ai.ready && ai.provider != Provider.custom && (await KeyVault.read(ai.provider)).isEmpty;
    notifyListeners();
  }

  Future<void> saveAi(AiConfig c) async {
    ai = c;
    keyMissing = false;
    notifyListeners();
    await _settings.put('ai', jsonEncode(c.toJson()));
  }

  Future<void> setHealth({bool? connected, bool? eatBack}) async {
    if (connected != null) healthConnected = connected;
    if (eatBack != null) this.eatBack = eatBack;
    notifyListeners();
    await _settings.put('health', '$healthConnected');
    await _settings.put('eatBack', '${this.eatBack}');
  }

  Future<void> setReminders({bool? on, Meal? meal, int? minutes}) async {
    if (on != null) remindersOn = on;
    if (meal != null && minutes != null) _reminderMinutes[meal] = minutes;
    notifyListeners();
    await _settings.put('reminders', '$remindersOn');
    if (meal != null && minutes != null) await _settings.put('remind_${meal.name}', '$minutes');
  }

  /// A suggested goal update from the user's own data, unless snoozed.
  CheckIn? get checkIn {
    final now = DateTime.now();
    if (_checkInQuietUntil != null && now.isBefore(_checkInQuietUntil!)) return null;
    return CheckIn.compute(
      profile: profile,
      kcalByDay: {for (final d in loggedDays) d: totalOn(d).kcal},
      weights: weights,
      today: now,
    );
  }

  Future<void> _quietCheckIn(Duration d) async {
    _checkInQuietUntil = DateTime.now().add(d);
    await _settings.put('checkInQuiet', '${_checkInQuietUntil!.millisecondsSinceEpoch}');
  }

  /// Use the measured maintenance from now on. Re-checks in two weeks.
  Future<void> acceptCheckIn(CheckIn c) async {
    await _quietCheckIn(const Duration(days: 14));
    await saveProfile(
      profile.copyWith(learnedMaintenance: () => c.measured, customKcal: () => null),
    );
  }

  Future<void> snoozeCheckIn() async {
    await _quietCheckIn(const Duration(days: 7));
    notifyListeners();
  }

  /// A cached weekly recap for the week starting [monday], as JSON.
  String? weekRecap(DateTime monday) => _settings.get('week_${_ymd(monday)}');

  Future<void> putWeekRecap(DateTime monday, String json) =>
      _settings.put('week_${_ymd(monday)}', json);

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> setTheme(String v) async {
    theme = v;
    notifyListeners();
    await _settings.put('theme', v);
  }

  Future<void> setAiOnly(bool v) async {
    aiOnly = v;
    notifyListeners();
    await _settings.put('aiOnly', '$v');
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    notifyListeners();
    await _settings.put('onboarded', 'true');
    if (_weightList.isEmpty) await logWeight(DateTime.now(), profile.weightKg);
  }

  // Entries

  List<Entry> entriesOn(DateTime day) => _byDay[dayOf(day)] ?? const [];

  Nutrients totalOn(DateTime day) => entriesOn(day).fold(Nutrients.zero, (s, e) => s + e.total);

  bool hasLog(DateTime day) => _byDay.containsKey(dayOf(day));

  Iterable<DateTime> get loggedDays => _byDay.keys;

  Entry? entry(String id) => _all.where((e) => e.id == id).firstOrNull;

  /// Days in a row with at least one entry, ending today (or yesterday, so
  /// the streak doesn't look broken first thing in the morning).
  int get streak {
    var d = dayOf(DateTime.now());
    if (!hasLog(d)) d = addDays(d, -1);
    var n = 0;
    while (hasLog(d)) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  Future<void> putEntry(Entry e) async {
    _all.removeWhere((x) => x.id == e.id);
    _all.add(e);
    _reindex();
    for (final item in e.items) {
      remember(item);
    }
    notifyListeners();
    await _entries.put(e.id, jsonEncode(e.toJson()));
  }

  Future<void> deleteEntry(String id) async {
    _all.removeWhere((x) => x.id == id);
    _reindex();
    notifyListeners();
    await _entries.delete(id);
  }

  /// Logs [entries] again on [day], keeping each one's meal and time of day.
  Future<List<Entry>> copyTo(List<Entry> entries, DateTime day) async {
    final copies = [
      for (final e in entries)
        Entry(
          id: newId(),
          at: DateTime(day.year, day.month, day.day, e.at.hour, e.at.minute),
          meal: e.meal,
          title: e.title,
          text: e.text,
          items: e.items,
        ),
    ];
    _all.addAll(copies);
    _reindex();
    notifyListeners();
    await _entries.putAll({for (final c in copies) c.id: jsonEncode(c.toJson())});
    return copies;
  }

  /// Distinct recent plates, newest first, for one-tap re-logging.
  List<Entry> recents({int limit = 12}) {
    final seen = <String>{};
    final out = <Entry>[];
    for (final e in _all.reversed) {
      if (seen.add(e.title.toLowerCase())) out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }

  // Waiting to be read

  List<PendingLog> get pending => List.unmodifiable(_pendingList);

  List<PendingLog> pendingOn(DateTime day) =>
      _pendingList.where((p) => dayOf(p.at) == dayOf(day)).toList();

  Future<void> addPending(PendingLog p) async {
    _pendingList.add(p);
    notifyListeners();
    await _pending.put(p.id, jsonEncode(p.toJson()));
  }

  Future<void> removePending(String id) async {
    _pendingList.removeWhere((p) => p.id == id);
    notifyListeners();
    await _pending.delete(id);
  }

  // Favourites

  List<Favourite> get favourites => List.unmodifiable(_favList);

  bool isFavourite(String title) =>
      _favList.any((f) => f.title.toLowerCase() == title.toLowerCase());

  Future<void> addFavourite(Entry e) async {
    if (isFavourite(e.title)) return;
    final f = Favourite(id: newId(), title: e.title, items: e.items, meal: e.meal);
    _favList.add(f);
    notifyListeners();
    await _favs.put(f.id, jsonEncode(f.toJson()));
  }

  Future<void> removeFavourite(String title) async {
    final gone = _favList.where((f) => f.title.toLowerCase() == title.toLowerCase()).toList();
    _favList.removeWhere(gone.contains);
    notifyListeners();
    for (final f in gone) {
      await _favs.delete(f.id);
    }
  }

  // Weight

  List<WeightEntry> get weights => List.unmodifiable(_weightList);

  Future<void> logWeight(DateTime day, double kgValue) async {
    final d = dayOf(day);
    _weightList.removeWhere((w) => w.day == d);
    _weightList
      ..add(WeightEntry(day: d, kg: kgValue))
      ..sort((a, b) => a.day.compareTo(b.day));
    if (d == dayOf(DateTime.now()) || _weightList.last.day == d) {
      profile = profile.copyWith(weightKg: kgValue);
      await _settings.put('profile', jsonEncode(profile.toJson()));
    }
    notifyListeners();
    await _weights.put(
      d.millisecondsSinceEpoch.toString(),
      jsonEncode(WeightEntry(day: d, kg: kgValue).toJson()),
    );
  }

  Future<void> deleteWeight(DateTime day) async {
    _weightList.removeWhere((w) => w.day == dayOf(day));
    if (_weightList.isNotEmpty && _weightList.last.kg != profile.weightKg) {
      profile = profile.copyWith(weightKg: _weightList.last.kg);
      await _settings.put('profile', jsonEncode(profile.toJson()));
    }
    notifyListeners();
    await _weights.delete(dayOf(day).millisecondsSinceEpoch.toString());
  }

  // Food memory: the last confirmed version of a food, reused next time so
  // repeat meals are consistent and cost no lookup.

  static String memoryKey(String name) => name.toLowerCase().trim();

  FoodItem? recall(String name) {
    final v = _memory.get(memoryKey(name));
    return v == null ? null : FoodItem.fromJson(_map(v));
  }

  void remember(FoodItem item) {
    if (item.source == Source.ai) return;
    // Weighed foods keep their amount, so "rice" next time is the usual
    // portion rather than 1 g; counted ones are stored per unit.
    _memory.put(
      memoryKey(item.name),
      jsonEncode((item.byWeight ? item : item.copyWith(qty: 1)).toJson()),
    );
  }

  // Backup

  String exportJson() => const JsonEncoder.withIndent(' ').convert({
    'app': 'nomnom',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': profile.toJson(),
    'ai': ai.toJson(),
    'entries': _all.map((e) => e.toJson()).toList(),
    'favourites': _favList.map((e) => e.toJson()).toList(),
    'weights': _weightList.map((e) => e.toJson()).toList(),
    'memory': {for (final k in _memory.keys) k: jsonDecode(_memory.get(k)!)},
  });

  /// Replaces everything with a backup. Throws [FormatException] on junk.
  Future<int> importJson(String raw) async {
    final j = jsonDecode(raw);
    if (j is! Map || j['app'] != 'nomnom') {
      throw const FormatException('Not a nomnom backup');
    }
    // Read everything before touching what's stored, so a bad backup
    // leaves the current data as it was.
    final List<Entry> entries;
    final List<Favourite> favs;
    final List<WeightEntry> weights;
    final Map<String, dynamic> mem;
    try {
      entries = [
        for (final e in j['entries'] as List) Entry.fromJson(Map<String, dynamic>.from(e)),
      ];
      favs = [
        for (final f in (j['favourites'] as List? ?? []))
          Favourite.fromJson(Map<String, dynamic>.from(f)),
      ];
      weights = [
        for (final w in (j['weights'] as List? ?? []))
          WeightEntry.fromJson(Map<String, dynamic>.from(w)),
      ];
      mem = Map<String, dynamic>.from(j['memory'] as Map? ?? {});
      if (j['profile'] != null) Profile.fromJson(Map<String, dynamic>.from(j['profile']));
    } catch (e) {
      throw FormatException('Damaged backup: $e');
    }
    await _entries.clear();
    await _favs.clear();
    await _weights.clear();
    await _memory.clear();
    await _pending.clear();
    await _settings.delete('checkInQuiet');
    await _entries.putAll({for (final e in entries) e.id: jsonEncode(e.toJson())});
    await _favs.putAll({for (final f in favs) f.id: jsonEncode(f.toJson())});
    await _weights.putAll({
      for (final w in weights)
        dayOf(w.day).millisecondsSinceEpoch.toString(): jsonEncode(w.toJson()),
    });
    await _memory.putAll(mem.map((k, v) => MapEntry(k, jsonEncode(v))));
    if (j['profile'] != null) {
      await _settings.put('profile', jsonEncode(j['profile']));
    }
    if (j['ai'] != null) await _settings.put('ai', jsonEncode(j['ai']));
    await _settings.put('onboarded', 'true');
    _load();
    notifyListeners();
    return _all.length;
  }

  Future<void> wipe() async {
    await Future.wait([
      _settings.clear(),
      _entries.clear(),
      _favs.clear(),
      _weights.clear(),
      _memory.clear(),
      _pending.clear(),
      KeyVault.clear(),
      Inbox.clear().catchError((_) {}),
    ]);
    _load();
    notifyListeners();
  }
}
