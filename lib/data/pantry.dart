import 'dart:math' as math;

import '../nutrition/food_db.dart';
import '../nutrition/local_parser.dart';
import 'models.dart';

/// Something kept at home and counted down as it's eaten: "10 eggs",
/// "450 g chicken breast". Weights are as bought, normally raw.
class StockItem {
  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.left,
    required this.full,
    required this.added,
    this.ref,
    this.pieceGrams = 0,
    this.raw = true,
    this.lowAt,
    this.useBy,
    this.links = const {},
    this.unlinks = const {},
  });

  final String id;
  final String name;

  /// 'piece', 'g' or 'ml'.
  final String unit;

  /// What's left, in [unit].
  final double left;

  /// The amount at the last restock, for the bar and the default low mark.
  final double full;

  /// Logs from before this aren't taken from it.
  final DateTime added;

  /// The food it matched when added, for exact matches later.
  final String? ref;

  /// Grams in one piece, to turn "100 g egg" into eggs.
  final double pieceGrams;

  /// Weighed raw (as bought). Cooked amounts are converted back.
  final bool raw;

  /// Warn at or below this; defaults to 2 pieces or a fifth of [full].
  final double? lowAt;
  final DateTime? useBy;

  /// Food names confirmed to come from this stock, and names that never do.
  final Set<String> links;
  final Set<String> unlinks;

  bool get counted => unit == 'piece';
  double get lowMark => lowAt ?? (counted ? math.min(2, full / 2) : full * 0.2);
  bool get isLow => left > 0 && left <= lowMark;
  bool get isOut => left <= 0;

  String amount([double? v]) => formatStock(v ?? left, unit);

  StockItem copyWith({
    String? name,
    double? left,
    double? full,
    double? pieceGrams,
    bool? raw,
    double? Function()? lowAt,
    DateTime? Function()? useBy,
    Set<String>? links,
    Set<String>? unlinks,
  }) => StockItem(
    id: id,
    name: name ?? this.name,
    unit: unit,
    left: left ?? this.left,
    full: full ?? this.full,
    added: added,
    ref: ref,
    pieceGrams: pieceGrams ?? this.pieceGrams,
    raw: raw ?? this.raw,
    lowAt: lowAt == null ? this.lowAt : lowAt(),
    useBy: useBy == null ? this.useBy : useBy(),
    links: links ?? this.links,
    unlinks: unlinks ?? this.unlinks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'n': name,
    'u': unit,
    'l': left,
    'f': full,
    'a': added.millisecondsSinceEpoch,
    if (ref != null) 'r': ref,
    if (pieceGrams > 0) 'pg': pieceGrams,
    if (!raw) 'raw': false,
    if (lowAt != null) 'lo': lowAt,
    if (useBy != null) 'ub': useBy!.millisecondsSinceEpoch,
    if (links.isNotEmpty) 'ln': links.toList(),
    if (unlinks.isNotEmpty) 'un': unlinks.toList(),
  };

  factory StockItem.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num).toDouble();
    return StockItem(
      id: j['id'] as String,
      name: j['n'] as String,
      unit: j['u'] as String,
      left: d(j['l']),
      full: d(j['f']),
      added: DateTime.fromMillisecondsSinceEpoch(j['a'] as int),
      ref: j['r'] as String?,
      pieceGrams: j['pg'] == null ? 0 : d(j['pg']),
      raw: j['raw'] != false,
      lowAt: j['lo'] == null ? null : d(j['lo']),
      useBy: j['ub'] == null ? null : DateTime.fromMillisecondsSinceEpoch(j['ub'] as int),
      links: {...(j['ln'] as List? ?? const []).cast<String>()},
      unlinks: {...(j['un'] as List? ?? const []).cast<String>()},
    );
  }
}

String formatStock(double v, String unit) {
  final n = formatNum((v * 10).round() / 10);
  return switch (unit) {
    'piece' => n,
    'ml' => v >= 1000 ? '${formatNum((v / 100).round() / 10)} l' : '$n ml',
    _ => v >= 1000 ? '${formatNum((v / 100).round() / 10)} kg' : '$n g',
  };
}

/// Cooked weight per raw gram, for foods whose yield is steady enough to
/// convert without asking. Grains and pulses vary with the water used, and
/// mixed dishes hold an unknown share, so those are asked.
const _yields = <String, double>{
  'chicken': 0.75,
  'turkey': 0.75,
  'beef': 0.72,
  'mutton': 0.7,
  'lamb': 0.72,
  'goat': 0.7,
  'pork': 0.72,
  'fish': 0.8,
  'salmon': 0.8,
  'tuna': 0.8,
  'prawn': 0.85,
  'shrimp': 0.85,
  'paneer': 1,
  'tofu': 1,
  'egg': 1,
  'potato': 1,
  'mushroom': 0.65,
  'spinach': 0.4,
};

double? cookedYield(String name) {
  final t = tokenize(name);
  for (final e in _yields.entries) {
    if (t.contains(e.key)) return e.value;
  }
  return null;
}

const _ignore = {
  'veg',
  'fresh',
  'raw',
  'cooked',
  'boiled',
  'fried',
  'grilled',
  'roasted',
  'baked',
  'whole',
  'large',
  'medium',
  'small',
  'organic',
  'homemade',
  'breast',
  'thigh',
  'boneless',
  'skinless',
  'fillet',
};

Set<String> _key(String s) => tokenize(s).difference(_ignore);

/// What a planned meal does to one stock item.
class StockUse {
  StockUse({
    required this.item,
    required this.stock,
    required this.amount,
    this.ask,
    this.suggested,
    this.note,
  });

  /// Index of the food item in the entry.
  final int item;
  final StockItem stock;

  /// In the stock's unit; null while [ask] is unanswered.
  double? amount;

  /// Why the user has to confirm, or null when it's certain.
  StockAsk? ask;

  /// A starting value for the question (the converted or available amount).
  final double? suggested;

  /// How the amount was worked out ("250 g cooked ≈ 333 g raw").
  final String? note;
}

enum StockAsk {
  /// The names look alike but the user never confirmed this food uses it.
  link,

  /// How much of the stock went in can't be worked out (a dish, a grain).
  amount,

  /// The meal takes more than the pantry says is left.
  short,
}

/// Works out which stock each food in a meal comes from and how much.
/// [previous] is what this entry took before (when editing), which is back
/// on the shelf for this calculation.
List<StockUse> planStock(
  List<FoodItem> items,
  List<StockItem> stock, {
  required DateTime at,
  Map<String, double> previous = const {},
}) {
  final out = <StockUse>[];
  final taken = <String, double>{};
  for (var i = 0; i < items.length; i++) {
    final f = items[i];
    final name = f.name.toLowerCase().trim();
    StockItem? pick;
    var sure = false;
    for (final s in stock) {
      if (s.unlinks.contains(name) || dayOf(at).isBefore(dayOf(s.added))) continue;
      final exact = s.links.contains(name) || (s.ref != null && s.ref == f.ref);
      final want = _key(s.name);
      final loose = want.isNotEmpty && _key('${f.name} ${f.refName ?? ''}').containsAll(want);
      if (exact) {
        pick = s;
        sure = true;
        break;
      }
      if (loose) pick ??= s;
    }
    if (pick == null) continue;

    final (amount, suggested, note) = _amount(f, pick);
    final available = pick.left + (previous[pick.id] ?? 0) - (taken[pick.id] ?? 0);
    final use = StockUse(
      item: i,
      stock: pick,
      amount: amount,
      suggested: suggested ?? amount,
      note: note,
      ask: !sure
          ? StockAsk.link
          : amount == null
          ? StockAsk.amount
          : amount > available + 1e-6
          ? StockAsk.short
          : null,
    );
    if (use.ask == StockAsk.short) use.amount = math.max(0, available);
    if (use.ask == null) taken[pick.id] = (taken[pick.id] ?? 0) + amount!;
    out.add(use);
  }
  return out;
}

/// The amount of [s] in [f], in the stock's unit, or null when it has to be
/// asked (with a suggestion when there's a likely answer).
(double?, double?, String?) _amount(FoodItem f, StockItem s) {
  // A dish that merely contains the stock ("chicken biryani" from chicken
  // breast) holds an unknown share of it.
  final mixed = f.source == Source.dish && !_key(s.name).containsAll(_key(f.name));
  if (mixed) return (null, null, null);

  if (s.counted) {
    if (f.unit == 'piece') return (f.qty, null, null);
    if (s.pieceGrams > 0) {
      final n = (f.grams / s.pieceGrams * 2).round() / 2;
      return (n, null, '${formatNum(f.grams.roundToDouble())} g ≈ ${formatNum(n)}');
    }
    return (null, null, null);
  }

  final grams = (f.unit == 'ml' && s.unit == 'ml' ? f.qty : f.grams).roundToDouble();
  if (!s.raw) return (grams, null, null);
  final state = f.source == Source.dish ? 'cooked' : foodState('${f.refName ?? ''} ${f.name}');
  final y = cookedYield(s.name);
  if (state == 'raw' || y == 1) return (grams, null, null);
  if (state == 'cooked') {
    if (y == null) return (null, null, null);
    final raw = (grams / y).roundToDouble();
    return (raw, null, '${formatNum(grams)} g cooked ≈ ${formatNum(raw)} g raw');
  }
  // Not said either way. For meat and fish it matters by a quarter.
  if (y != null) {
    return (
      null,
      grams,
      'If ${formatNum(grams)} g was cooked weight, that’s about ${formatNum((grams / y).roundToDouble())} g raw.',
    );
  }
  return (grams, null, null);
}

/// A line of shopping read into a stock item, before it's saved.
class StockDraft {
  StockDraft({
    required this.name,
    required this.amount,
    required this.unit,
    this.ref,
    this.pieceGrams = 0,
    this.raw = true,
  });

  String name;
  double amount;
  String unit;
  String? ref;
  double pieceGrams;
  bool raw;

  StockItem toItem(String id, DateTime now) => StockItem(
    id: id,
    name: name,
    unit: unit,
    left: amount,
    full: amount,
    added: now,
    ref: ref,
    pieceGrams: pieceGrams,
    raw: raw,
  );
}

const _stockUnits = {
  'g': ('g', 1.0),
  'gm': ('g', 1.0),
  'gms': ('g', 1.0),
  'gram': ('g', 1.0),
  'grams': ('g', 1.0),
  'kg': ('g', 1000.0),
  'kgs': ('g', 1000.0),
  'kilo': ('g', 1000.0),
  'kilos': ('g', 1000.0),
  'ml': ('ml', 1.0),
  'l': ('ml', 1000.0),
  'litre': ('ml', 1000.0),
  'litres': ('ml', 1000.0),
  'liter': ('ml', 1000.0),
  'liters': ('ml', 1000.0),
  'pc': ('piece', 1.0),
  'pcs': ('piece', 1.0),
  'piece': ('piece', 1.0),
  'pieces': ('piece', 1.0),
  'dozen': ('piece', 12.0),
  'pack': ('piece', 1.0),
  'packs': ('piece', 1.0),
  'packet': ('piece', 1.0),
  'packets': ('piece', 1.0),
};

/// Reads "10 eggs, 450g chicken breast, 2 dozen bananas, milk 1 l" on the
/// phone. Each line needs an amount; returns null if any line has none, so
/// nothing is guessed.
List<StockDraft>? readStock(String text, FoodDb db, {String? country}) {
  final out = <StockDraft>[];
  final chunks = text
      .toLowerCase()
      .split(RegExp(r',|\band\b|\n|;|\+'))
      .map((c) => c.trim().replaceAll(RegExp(r'\s+'), ' '))
      .where((c) => c.isNotEmpty);
  const num = r'(\d+(?:\.\d+)?|a|an|one|half)';
  final units = _stockUnits.keys.join('|');
  final lead = RegExp(
    '^$num'
    r'\s*('
    '$units'
    r')?\b\s*(?:of\s+)?(.+)$',
  );
  final trail = RegExp(
    r'^(.+?)\s+'
    '$num'
    r'\s*('
    '$units'
    r')?$',
  );
  for (final c in chunks) {
    String? n, u, name;
    if (lead.firstMatch(c) case final m?) {
      (n, u, name) = (m.group(1), m.group(2), m.group(3));
    } else if (trail.firstMatch(c) case final m?) {
      (name, n, u) = (m.group(1), m.group(2), m.group(3));
    } else {
      return null;
    }
    // "a dozen eggs": the count word is the unit.
    if (u == null && name!.startsWith('dozen ')) {
      u = 'dozen';
      name = name.substring(6);
    }
    final count = switch (n) {
      'a' || 'an' || 'one' => 1.0,
      'half' => 0.5,
      _ => double.parse(n!),
    };
    final (unit, factor) = _stockUnits[u] ?? ('piece', 1.0);
    final clean = name!.trim();
    if (clean.isEmpty) return null;

    final food = _groceryMatch(clean, db, country);
    out.add(
      StockDraft(
        name: clean[0].toUpperCase() + clean.substring(1),
        amount: count * factor,
        unit: unit,
        ref: food?.id,
        pieceGrams: food == null ? 0 : (portionGrams(food, 'piece') ?? 0),
        raw: foodState(clean) != 'cooked',
      ),
    );
  }
  return out.isEmpty ? null : out;
}

/// Processed forms nobody means when they say they bought "eggs".
const _processed = {
  'dried',
  'dehydrated',
  'powder',
  'powdered',
  'breaded',
  'frozen',
  'canned',
  'substitute',
  'white',
  'yolk',
  'tenders',
  'nuggets',
  'mixture',
  'imitation',
  'buttermilk',
  'condensed',
  'evaporated',
  'dry',
  'flavored',
  'sweetened',
  'cooked',
  'fried',
  'scrambled',
  'omelet',
};

/// The table entry for a grocery as bought: the plain raw one when there
/// is one, never a dried, breaded or prepared form the user didn't name.
DbFood? _groceryMatch(String name, FoodDb db, String? country) {
  final want = _key(name);
  if (want.isEmpty) return null;
  final said = tokenize(name);
  final hits = db
      .search('$name raw', country: country, limit: 20)
      .where((f) => f.tokens.containsAll(want))
      .toList();
  double score(DbFood f, int rank) {
    final words = tokenize(f.name);
    final odd = words.where((w) => _processed.contains(w) && !said.contains(w)).length;
    // USDA names lead with the kind of food: "Nuts, coconut milk" is not milk.
    final kind = tokenize(f.name.split(',').first).difference(said).length;
    return (words.contains('raw') ? 2 : 0) +
        (words.contains('whole') ? 0.5 : 0) -
        odd * 3 -
        kind * 2.5 -
        words.difference(said).length * 0.1 -
        rank * 0.05;
  }

  DbFood? best;
  var top = -1e9;
  for (var i = 0; i < hits.length; i++) {
    final s = score(hits[i], i);
    if (s > top) {
      top = s;
      best = hits[i];
    }
  }
  return best;
}
