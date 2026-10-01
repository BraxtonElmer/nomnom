import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../nutrition/check_in.dart';
import '../nutrition/targets.dart';
import 'inbox.dart';
import 'keys.dart';
import 'models.dart';
import 'pantry.dart';

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
  late Box<String> _stock;

  Profile profile = const Profile();
  AiConfig ai = const AiConfig();
  bool onboarded = false;
  bool healthConnected = false;

  /// Add active calories burned to the day's budget.
  bool eatBack = false;

  bool remindersOn = false;

  /// Pantry notifications: low, out and use-by.
  bool stockAlerts = true;

  /// Days before a use-by date to send its alert (0 is the morning of).
  int useByDays = 1;

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
  final List<StockItem> _stockList = [];

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
    _stock = await Hive.openBox<String>('stock');
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
    stockAlerts = _settings.get('stockAlerts') != 'false';
    StockItem.lowPieces = double.tryParse(_settings.get('lowPieces') ?? '') ?? 2;
    StockItem.lowPercent = double.tryParse(_settings.get('lowPercent') ?? '') ?? 20;
    useByDays = int.tryParse(_settings.get('useByDays') ?? '') ?? 1;
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
    _stockList
      ..clear()
      ..addAll(_stock.values.map((v) => StockItem.fromJson(_map(v))))
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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

  /// Default warning points for pantry items without their own.
  Future<void> setLowDefaults({double? pieces, double? percent, int? useBy}) async {
    if (pieces != null) StockItem.lowPieces = pieces;
    if (percent != null) StockItem.lowPercent = percent;
    if (useBy != null) useByDays = useBy;
    notifyListeners();
    if (pieces != null) await _settings.put('lowPieces', '$pieces');
    if (percent != null) await _settings.put('lowPercent', '$percent');
    if (useBy != null) await _settings.put('useByDays', '$useBy');
  }

  Future<void> setStockAlerts(bool v) async {
    stockAlerts = v;
    notifyListeners();
    await _settings.put('stockAlerts', '$v');
  }

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

  /// Saves [e]. Its pantry use is worked out here when it isn't set, and
  /// stock moves by the difference from what the entry took before, so
  /// edits, deletes, undo and copies all keep the pantry right.
  Future<void> putEntry(Entry e) async {
    final old = entry(e.id);
    final before = old?.stock ?? const {};
    e = _capStock(
      _planStock(e, before),
      before,
    ).copyWith(logged: old?.logged ?? e.logged ?? DateTime.now());
    _all.removeWhere((x) => x.id == e.id);
    _all.add(e);
    await _moveStock(before, e.stock ?? const {}, logged: e.logged);
    _reindex();
    for (final item in e.items) {
      remember(item);
    }
    notifyListeners();
    await _entries.put(e.id, jsonEncode(e.toJson()));
  }

  Future<void> deleteEntry(String id) async {
    final old = entry(id);
    final before = old?.stock ?? const {};
    _all.removeWhere((x) => x.id == id);
    if (old != null) await _moveStock(before, const {}, logged: old.logged);
    _reindex();
    notifyListeners();
    await _entries.delete(id);
  }

  /// Logs [entries] again on [day], keeping each one's meal and time of day.
  Future<List<Entry>> copyTo(List<Entry> entries, DateTime day) async {
    final copies = <Entry>[];
    for (final e in entries) {
      // Eaten again: take what the original took, as already answered;
      // work it out afresh only when the original took nothing.
      final source = e.stockCheck || (e.stock?.isEmpty ?? true) ? null : e.stock;
      final c = _capStock(
        _planStock(
          Entry(
            id: newId(),
            at: DateTime(day.year, day.month, day.day, e.at.hour, e.at.minute),
            meal: e.meal,
            title: e.title,
            text: e.text,
            items: e.items,
            logged: DateTime.now(),
            stock: source == null
                ? null
                : {
                    for (final MapEntry(:key, :value) in source.entries)
                      if (stockItem(key) case final s? when !dayOf(day).isBefore(dayOf(s.added)))
                        key: value,
                  },
          ),
          const {},
        ),
        const {},
      );
      await _moveStock(const {}, c.stock!, logged: c.logged);
      copies.add(c);
    }
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

  // Pantry

  List<StockItem> get stock => List.unmodifiable(_stockList);

  StockItem? stockItem(String id) => _stockList.where((s) => s.id == id).firstOrNull;

  /// Entries whose pantry use needs the user.
  List<Entry> get stockChecks =>
      _all.where((e) => e.stockCheck).toList()..sort((a, b) => b.at.compareTo(a.at));

  /// Called when an item goes low, runs out or changes use-by date; set by
  /// the alerts so the store doesn't depend on notifications.
  static void Function(StockItem before, StockItem after)? onStockChanged;

  /// [logged] marks a change made by logging a meal, which is the only kind
  /// that sends a low or out alert (not a hand recount).
  Future<void> putStock(StockItem s, {bool logged = false}) async {
    final before = stockItem(s.id);
    _stockList
      ..removeWhere((x) => x.id == s.id)
      ..add(s)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _stock.put(s.id, jsonEncode(s.toJson()));
    if (before != null && logged) onStockChanged?.call(before, s);
  }

  Future<void> deleteStock(String id) async {
    _stockList.removeWhere((x) => x.id == id);
    notifyListeners();
    await _stock.delete(id);
  }

  /// Remember that a food [name] comes (or never comes) from stock [id].
  Future<void> linkStock(String id, String name, {required bool yes}) async {
    final s = stockItem(id);
    if (s == null) return;
    final n = name.toLowerCase().trim();
    await putStock(
      s.copyWith(
        links: yes ? {...s.links, n} : ({...s.links}..remove(n)),
        unlinks: yes ? ({...s.unlinks}..remove(n)) : {...s.unlinks, n},
      ),
    );
  }

  Entry _planStock(Entry e, Map<String, double> before) {
    if (e.stock != null) return e;
    if (_stockList.isEmpty) return e.copyWith(stock: () => {});
    final plan = planStock(e.items, _stockList, at: e.at, previous: before);
    final use = <String, double>{};
    for (final u in plan.where((u) => u.ask == null)) {
      use[u.stock.id] = (use[u.stock.id] ?? 0) + u.amount!;
    }
    return e.copyWith(stock: () => use, stockCheck: plan.any((u) => u.ask != null));
  }

  /// An entry never records taking more than was on the shelf, so deleting
  /// it can't put back more than it took.
  Entry _capStock(Entry e, Map<String, double> before) {
    final use = e.stock;
    if (use == null || use.isEmpty) return e;
    final capped = {
      for (final MapEntry(:key, :value) in use.entries)
        if (stockItem(key) case final s?)
          key: value.clamp(0, s.left + (before[key] ?? 0)).toDouble(),
    };
    return e.copyWith(stock: () => capped);
  }

  /// Moves stock by the change in what a meal takes. A meal saved before a
  /// hand recount is already in that count, so it moves nothing.
  Future<void> _moveStock(
    Map<String, double> before,
    Map<String, double> after, {
    required DateTime? logged,
  }) async {
    for (final id in {...before.keys, ...after.keys}) {
      final delta = (after[id] ?? 0) - (before[id] ?? 0);
      final s = stockItem(id);
      if (s == null || delta.abs() < 1e-9) continue;
      if (s.recount != null && (logged == null || logged.isBefore(s.recount!))) continue;
      await putStock(s.copyWith(left: max(0, s.left - delta)), logged: true);
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
    'stock': _stockList.map((e) => e.toJson()).toList(),
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
    final List<StockItem> stock;
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
      stock = [
        for (final s in (j['stock'] as List? ?? []))
          StockItem.fromJson(Map<String, dynamic>.from(s)),
      ];
      if (j['profile'] != null) Profile.fromJson(Map<String, dynamic>.from(j['profile']));
    } catch (e) {
      throw FormatException('Damaged backup: $e');
    }
    await _entries.clear();
    await _favs.clear();
    await _weights.clear();
    await _memory.clear();
    await _pending.clear();
    await _stock.clear();
    await _settings.delete('checkInQuiet');
    await _entries.putAll({for (final e in entries) e.id: jsonEncode(e.toJson())});
    await _favs.putAll({for (final f in favs) f.id: jsonEncode(f.toJson())});
    await _weights.putAll({
      for (final w in weights)
        dayOf(w.day).millisecondsSinceEpoch.toString(): jsonEncode(w.toJson()),
    });
    await _memory.putAll(mem.map((k, v) => MapEntry(k, jsonEncode(v))));
    await _stock.putAll({for (final s in stock) s.id: jsonEncode(s.toJson())});
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
      _stock.clear(),
      KeyVault.clear(),
      Inbox.clear().catchError((_) {}),
    ]);
    _load();
    notifyListeners();
  }
}
