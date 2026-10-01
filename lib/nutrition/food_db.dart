import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import 'cuisines.dart';

/// A food from a bundled table, with nutrition per 100 g.
class DbFood {
  DbFood({
    required this.id,
    required this.name,
    required this.source,
    required this.per100,
    required this.portions,
    required this.tokens,
    required this.head,
    required this.first,
    required this.length,
    Set<String>? front,
    this.cuisine,
  }) : front = front ?? head;

  final String id;
  final String name;
  final Source source;
  final Nutrients per100;
  final List<(String, double)> portions;
  final Set<String> tokens;

  /// Tokens of the leading phrase ("Chicken" in "Chicken, broilers, ...").
  final Set<String> head;

  /// The very first word; "apple" for "Apples, raw" but not "Rose-apples".
  final String first;

  /// Tokens of the first two phrases ("Milk, buttermilk"): what the food is.
  final Set<String> front;

  /// Word count ignoring parenthetical notes, used to prefer plain entries.
  final int length;

  /// Set for regional dish tables.
  /// Set for dish tables, e.g. 'indian', 'chinese'.
  final String? cuisine;
}

class FoodDb {
  FoodDb._(this._foods) : _byId = {for (final f in _foods) f.id: f} {
    final df = <String, int>{};
    for (final f in _foods) {
      for (final t in f.tokens) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = _foods.length;
    _idf = df.map((t, c) => MapEntry(t, math.log((n + 1) / (c + 1)) + 1));
    _rare = math.log(n + 1) + 1;
  }

  final List<DbFood> _foods;
  final Map<String, DbFood> _byId;

  /// How distinctive each word is: "almond" counts, "raw" barely does.
  late final Map<String, double> _idf;
  late final double _rare;

  static FoodDb? _instance;
  static FoodDb get i => _instance!;
  static bool get loaded => _instance != null;

  @visibleForTesting
  static void use(FoodDb db) => _instance = db;

  static Future<FoodDb>? _loading;

  /// Safe to call repeatedly; every caller shares one load.
  static Future<FoodDb> load() =>
      _loading ??= _instance != null ? Future.value(_instance!) : _load();

  static Future<FoodDb> _load() async {
    final usda = await rootBundle.loadString('assets/data/usda.json');
    final dishes = {for (final c in cuisines) c.id: await rootBundle.loadString(c.asset)};
    final foods = await compute(_parse, (usda, dishes));
    return _instance = FoodDb._(foods);
  }

  /// For tests and tools that have the raw JSON at hand.
  /// [dishes] maps a cuisine id to its table's JSON.
  factory FoodDb.fromRaw(String usda, Map<String, String> dishes) =>
      FoodDb._(_parse((usda, dishes)));

  int get size => _foods.length;

  DbFood? get(String? id) => id == null ? null : _byId[id];

  /// Ranked matches for a free-text query. Cheap enough to run per keystroke.
  List<DbFood> search(String query, {String? country, int limit = 10}) {
    final q = tokenize(withSynonyms(query));
    if (q.isEmpty) return const [];
    final scored = <(DbFood, double)>[];
    for (final f in _foods) {
      var s = 0.0;
      var matched = 0;
      for (final t in q) {
        final w = _idf[t] ?? _rare;
        if (f.tokens.contains(t)) {
          s += w * (f.head.contains(t) ? 1.5 : 1);
          if (f.first == t) s += 1;
          matched++;
        } else if (t.length >= 3 && f.tokens.any((ft) => ft.startsWith(t))) {
          s += 0.4 * w;
          matched++;
        } else {
          s -= 0.6 * w;
        }
      }
      if (matched == 0) continue;
      // Words up front that the query didn't ask for mean a different food.
      s -= 0.9 * f.front.where((t) => !q.contains(t)).length;
      s -= 0.1 * f.length;
      // Local food gets a nudge; nothing is penalised for being foreign.
      if (f.cuisine != null && (cuisineById(f.cuisine)?.countries.contains(country) ?? false)) {
        s += 1.5;
      }
      if (s > 0) scored.add((f, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }
}

/// Indian and British English food words mapped to the USDA vocabulary.
const _synonyms = [
  ('double toned', 'lowfat 1%'),
  ('full cream', 'whole'),
  ('full fat', 'whole'),
  ('toned', 'reduced fat 2%'),
  ('skimmed', 'nonfat'),
  ('brown bread', 'bread whole wheat'),
  ('white bread', 'bread white'),
  ('lady finger', 'okra'),
  ('ladyfinger', 'okra'),
  ('brinjal', 'eggplant'),
  ('aubergine', 'eggplant'),
  ('capsicum', 'peppers sweet'),
  ('courgette', 'zucchini'),
  ('maida', 'wheat flour white'),
  ('atta', 'wheat flour whole'),
  ('besan', 'chickpea flour'),
  ('groundnut', 'peanut'),
  ('sooji', 'semolina'),
  ('suji', 'semolina'),
  ('curd', 'yogurt plain curd'),
  ('prawn', 'shrimp'),
  ('mutton', 'lamb mutton'),
  ('biscuit', 'cookie biscuit'),
  ('crisps', 'potato chips'),
];

String withSynonyms(String q) {
  var out = ' ${q.toLowerCase()} ';
  for (final (from, to) in _synonyms) {
    out = out.replaceAll(RegExp('\\b$from\\b'), to);
  }
  return out.trim();
}

const _stop = {'with', 'and', 'of', 'a', 'an', 'the', 'in', 'on', 'or', 'for', 'to', 'some', 'my'};

String _stem(String t) {
  if (t.length > 4 && t.endsWith('ies')) return '${t.substring(0, t.length - 3)}y';
  if (t.length > 4 && t.endsWith('oes')) return t.substring(0, t.length - 2);
  if (t.length > 3 && t.endsWith('s') && !t.endsWith('ss')) return t.substring(0, t.length - 1);
  return t;
}

String _first(String name) {
  final m = RegExp(r'[a-z0-9]+').firstMatch(name.toLowerCase());
  return m == null ? '' : _stem(m.group(0)!);
}

Set<String> tokenize(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.isNotEmpty && !_stop.contains(t))
    .map(_stem)
    .toSet();

List<DbFood> _parse((String, Map<String, String>) raw) {
  final out = <DbFood>[];
  for (final MapEntry(key: cuisine, value: json) in raw.$2.entries) {
    for (final r in jsonDecode(json) as List) {
      final name = r[1] as String;
      out.add(
        DbFood(
          id: r[0] as String,
          name: name,
          source: Source.dish,
          cuisine: cuisine,
          per100: Nutrients.fromJson([r[3], r[4], r[5], r[6], r[7]]),
          portions: [for (final p in r[8] as List) (p[0] as String, (p[1] as num).toDouble())],
          tokens: tokenize('$name ${r[2]}'),
          head: tokenize(name),
          first: _first(name),
          length: tokenize(name).length,
        ),
      );
    }
  }
  for (final r in jsonDecode(raw.$1) as List) {
    final name = r[1] as String;
    out.add(
      DbFood(
        id: 'usda:${r[0]}',
        name: name,
        source: Source.usda,
        per100: Nutrients.fromJson([r[2], r[3], r[4], r[5], r[6]]).withMicros({
          if (r.length > 8)
            for (final (i, v) in (r[8] as List).indexed)
              if (v != null) Micro.values[i]: (v as num).toDouble(),
        }),
        portions: [for (final p in r[7] as List) (p[0] as String, (p[1] as num).toDouble())],
        tokens: tokenize(name),
        head: tokenize(name.split(',').first),
        front: tokenize(name.split(',').take(2).join(' ')),
        first: _first(name),
        length: tokenize(name.replaceAll(RegExp(r'\(.*?\)'), '')).length,
      ),
    );
  }
  return out;
}
