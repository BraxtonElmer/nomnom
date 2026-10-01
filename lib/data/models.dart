import 'dart:math' as math;

/// The nutrients beyond the big five, shown in details. [dv] is the daily
/// value used for % bars; [limit] marks ones you want to stay under.
enum Micro {
  sugar('Sugar', 'g', 50, limit: true),
  satFat('Saturated fat', 'g', 20, limit: true),
  sodium('Sodium', 'mg', 2300, limit: true),
  potassium('Potassium', 'mg', 4700),
  calcium('Calcium', 'mg', 1300),
  iron('Iron', 'mg', 18),
  vitaminC('Vitamin C', 'mg', 90),
  vitaminB12('Vitamin B12', 'mcg', 2.4);

  const Micro(this.label, this.unit, this.dv, {this.limit = false});
  final String label;
  final String unit;
  final double dv;
  final bool limit;
}

/// kcal + macros, plus whichever micronutrients are known. Used both per
/// 100 g and as absolute totals. A missing micro means "unknown", not zero.
class Nutrients {
  const Nutrients({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.micros = const {},
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final Map<Micro, double> micros;

  static const zero = Nutrients();

  Nutrients operator +(Nutrients o) => Nutrients(
    kcal: kcal + o.kcal,
    protein: protein + o.protein,
    carbs: carbs + o.carbs,
    fat: fat + o.fat,
    fiber: fiber + o.fiber,
    micros: {
      for (final m in {...micros.keys, ...o.micros.keys}) m: (micros[m] ?? 0) + (o.micros[m] ?? 0),
    },
  );

  Nutrients scale(double f) => Nutrients(
    kcal: kcal * f,
    protein: protein * f,
    carbs: carbs * f,
    fat: fat * f,
    fiber: fiber * f,
    micros: micros.map((k, v) => MapEntry(k, v * f)),
  );

  Nutrients withMicros(Map<Micro, double> m) =>
      Nutrients(kcal: kcal, protein: protein, carbs: carbs, fat: fat, fiber: fiber, micros: m);

  List<Object> toJson() => [
    ...[kcal, protein, carbs, fat, fiber].map(_r),
    if (micros.isNotEmpty) {for (final e in micros.entries) e.key.name: _r(e.value)},
  ];

  factory Nutrients.fromJson(List<dynamic> j) => Nutrients(
    kcal: _d(j[0]),
    protein: _d(j[1]),
    carbs: _d(j[2]),
    fat: _d(j[3]),
    fiber: j.length > 4 ? _d(j[4]) : 0,
    micros: j.length > 5 && j[5] is Map
        ? {
            for (final e in (j[5] as Map).entries)
              if (Micro.values.any((m) => m.name == e.key))
                Micro.values.byName(e.key as String): _d(e.value),
          }
        : const {},
  );
}

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d]'s calendar day moved by [n] days. Safe across clock changes, unlike
/// adding a 24-hour Duration.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Whole calendar days from [a] to [b].
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
double _r(double v) => (v * 100).roundToDouble() / 100;

enum Meal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  snack('Snack'),
  dinner('Dinner');

  const Meal(this.label);
  final String label;

  /// What you're probably eating at this hour.
  static Meal forTime(DateTime t) {
    final h = t.hour + t.minute / 60;
    if (h >= 4 && h < 11) return Meal.breakfast;
    if (h >= 11 && h < 15.5) return Meal.lunch;
    if (h >= 15.5 && h < 18.5) return Meal.snack;
    return Meal.dinner;
  }

  static Meal parse(Object? s) =>
      Meal.values.firstWhere((m) => m.name == s, orElse: () => Meal.snack);
}

/// Where an item's numbers come from. Shown on every item so you know how
/// much to trust it.
enum Source {
  usda('USDA'),
  dish('Dish table'),
  off('Open Food Facts'),
  ai('AI estimate'),
  manual('Manual');

  const Source(this.label);
  final String label;

  static Source parse(Object? s) =>
      Source.values.firstWhere((v) => v.name == s, orElse: () => Source.ai);
}

/// One food on a plate. Nutrition is stored per 100 g so changing the
/// amount is exact arithmetic, never another AI call.
class FoodItem {
  const FoodItem({
    required this.name,
    required this.qty,
    required this.unit,
    required this.unitGrams,
    required this.per100,
    required this.source,
    this.ref,
    this.refName,
    this.flagged = false,
    this.ai,
    this.richness = 0,
  });

  final String name;

  /// Count of [unit]. For gram-based items unit is 'g' and unitGrams is 1.
  final double qty;
  final String unit;
  final double unitGrams;
  final Nutrients per100;
  final Source source;
  final String? ref;
  final String? refName;

  /// Database value and AI estimate disagree a lot; worth a glance.
  final bool flagged;

  /// The model's own estimate per 100 g, kept for comparison and switching.
  final Nutrients? ai;

  /// For home-style dishes: -1 light on oil and ghee, 0 typical, 1 rich.
  /// Home cooking varies mostly in fat, so this moves fat by about a third.
  final int richness;

  /// [per100] with the oil and ghee adjustment applied.
  Nutrients get eff100 {
    if (richness == 0) return per100;
    final dFat = per100.fat * 0.35 * richness;
    return Nutrients(
      kcal: per100.kcal + dFat * 9,
      protein: per100.protein,
      carbs: per100.carbs,
      fat: per100.fat + dFat,
      fiber: per100.fiber,
      micros: per100.micros,
    );
  }

  /// AI estimate for this amount, when it exists and the numbers came from
  /// somewhere else.
  Nutrients? get aiTotal => (ai == null || source == Source.ai) ? null : ai!.scale(grams / 100);

  double get grams => qty * unitGrams;
  Nutrients get total => eff100.scale(grams / 100);
  bool get byWeight => unit == 'g' || unit == 'ml';

  String get qtyLabel => formatQty(qty, unit);

  FoodItem copyWith({
    String? name,
    double? qty,
    String? unit,
    double? unitGrams,
    Nutrients? per100,
    Source? source,
    String? ref,
    String? refName,
    bool? flagged,
    Nutrients? ai,
    int? richness,
  }) => FoodItem(
    name: name ?? this.name,
    qty: qty ?? this.qty,
    unit: unit ?? this.unit,
    unitGrams: unitGrams ?? this.unitGrams,
    per100: per100 ?? this.per100,
    source: source ?? this.source,
    ref: ref ?? this.ref,
    refName: refName ?? this.refName,
    flagged: flagged ?? this.flagged,
    ai: ai ?? this.ai,
    richness: richness ?? this.richness,
  );

  /// One stepper notch. Small for single pieces, 10% for weights.
  FoodItem step(int dir) {
    if (byWeight) {
      final s = grams < 50 ? 5.0 : (grams < 200 ? 10.0 : 25.0);
      final next = math.max(s, (qty / s).round() * s + dir * s);
      return copyWith(qty: next);
    }
    final s = qty <= 1 ? 0.5 : 1.0;
    final next = math.max(0.5, ((qty / s).round() * s) + dir * s);
    return copyWith(qty: next);
  }

  Map<String, dynamic> toJson() => {
    'n': name,
    'q': qty,
    'u': unit,
    'ug': unitGrams,
    'p': per100.toJson(),
    's': source.name,
    if (ref != null) 'r': ref,
    if (refName != null) 'rn': refName,
    if (flagged) 'f': true,
    if (ai != null && source != Source.ai) 'a': ai!.toJson(),
    if (richness != 0) 'rv': richness,
  };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
    name: j['n'] as String,
    qty: _d(j['q']),
    unit: j['u'] as String,
    unitGrams: _d(j['ug']),
    per100: Nutrients.fromJson(j['p'] as List),
    source: Source.parse(j['s']),
    ref: j['r'] as String?,
    refName: j['rn'] as String?,
    flagged: j['f'] == true,
    ai: j['a'] == null ? null : Nutrients.fromJson(j['a'] as List),
    richness: (j['rv'] as int?) ?? 0,
  );
}

String formatNum(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(v < 10 ? 1 : 0);
}

String formatQty(double qty, String unit) {
  final n = formatNum(qty);
  switch (unit) {
    case 'g':
    case 'ml':
      return '$n $unit';
    case 'piece':
      return qty == 1 ? '1 pc' : '$n pcs';
    default:
      if (qty == 1 || unit.endsWith('s') || const {'tbsp', 'tsp', 'oz'}.contains(unit)) {
        return '$n $unit';
      }
      return '$n ${unit}s';
  }
}

/// A logged meal: what you typed plus the items it became.
class Entry {
  const Entry({
    required this.id,
    required this.at,
    required this.meal,
    required this.title,
    required this.text,
    required this.items,
    this.note,
  });

  final String id;
  final DateTime at;
  final Meal meal;
  final String title;
  final String text;
  final List<FoodItem> items;
  final String? note;

  Nutrients get total => items.fold(Nutrients.zero, (s, i) => s + i.total);

  Entry copyWith({DateTime? at, Meal? meal, String? title, List<FoodItem>? items}) => Entry(
    id: id,
    at: at ?? this.at,
    meal: meal ?? this.meal,
    title: title ?? this.title,
    text: text,
    items: items ?? this.items,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'm': meal.name,
    't': title,
    'x': text,
    'i': items.map((e) => e.toJson()).toList(),
    if (note != null) 'n': note,
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    meal: Meal.parse(j['m']),
    title: j['t'] as String,
    text: (j['x'] as String?) ?? '',
    items: (j['i'] as List).map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e))).toList(),
    note: j['n'] as String?,
  );
}

/// Text typed while the AI couldn't be reached, waiting to be read.
class PendingLog {
  const PendingLog({required this.id, required this.at, required this.meal, required this.text});

  final String id;
  final DateTime at;
  final Meal meal;
  final String text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'm': meal.name,
    'x': text,
  };

  factory PendingLog.fromJson(Map<String, dynamic> j) => PendingLog(
    id: j['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
    meal: Meal.parse(j['m']),
    text: j['x'] as String,
  );
}

/// A saved plate you can re-log in one tap.
class Favourite {
  const Favourite({required this.id, required this.title, required this.items, this.meal});

  final String id;
  final String title;
  final List<FoodItem> items;
  final Meal? meal;

  Nutrients get total => items.fold(Nutrients.zero, (s, i) => s + i.total);

  Map<String, dynamic> toJson() => {
    'id': id,
    't': title,
    'm': meal?.name,
    'i': items.map((e) => e.toJson()).toList(),
  };

  factory Favourite.fromJson(Map<String, dynamic> j) => Favourite(
    id: j['id'] as String,
    title: j['t'] as String,
    meal: j['m'] == null ? null : Meal.parse(j['m']),
    items: (j['i'] as List).map((e) => FoodItem.fromJson(Map<String, dynamic>.from(e))).toList(),
  );
}

class WeightEntry {
  const WeightEntry({required this.day, required this.kg});

  final DateTime day;
  final double kg;

  Map<String, dynamic> toJson() => {'d': day.millisecondsSinceEpoch, 'kg': kg};

  factory WeightEntry.fromJson(Map<String, dynamic> j) =>
      WeightEntry(day: dayOf(DateTime.fromMillisecondsSinceEpoch(j['d'] as int)), kg: _d(j['kg']));
}

enum Sex { male, female }

enum Goal {
  lose('Lose weight'),
  maintain('Maintain'),
  gain('Gain weight');

  const Goal(this.label);
  final String label;
}

enum MacroPreset {
  balanced('Balanced', 0.25, 0.45, 0.30),
  highProtein('High protein', 0.35, 0.35, 0.30),
  lowCarb('Low carb', 0.30, 0.25, 0.45);

  const MacroPreset(this.label, this.protein, this.carbs, this.fat);
  final String label;
  final double protein;
  final double carbs;
  final double fat;
}

class Profile {
  const Profile({
    this.country = 'IN',
    this.metric = true,
    this.sex = Sex.male,
    this.age = 25,
    this.heightCm = 170,
    this.weightKg = 70,
    this.activity = 1.375,
    this.goal = Goal.maintain,
    this.paceKg = 0.5,
    this.customKcal,
    this.macros = MacroPreset.balanced,
    this.learnedMaintenance,
  });

  final String country;
  final bool metric;
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double activity;
  final Goal goal;

  /// kg per week, for lose / gain.
  final double paceKg;

  /// Set when the user picks their own daily target.
  final int? customKcal;
  final MacroPreset macros;

  /// Maintenance kcal measured from the user's own logs and weight trend,
  /// once they accept a goal check-in. Replaces the formula's guess.
  final double? learnedMaintenance;

  /// Age, height and weight are within sensible ranges.
  bool get bodyValid =>
      age >= 13 && age <= 120 && heightCm >= 100 && heightCm <= 250 && weightKg >= 30 && weightKg <= 300;

  Profile copyWith({
    String? country,
    bool? metric,
    Sex? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    double? activity,
    Goal? goal,
    double? paceKg,
    int? Function()? customKcal,
    MacroPreset? macros,
    double? Function()? learnedMaintenance,
  }) => Profile(
    country: country ?? this.country,
    metric: metric ?? this.metric,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    activity: activity ?? this.activity,
    goal: goal ?? this.goal,
    paceKg: paceKg ?? this.paceKg,
    customKcal: customKcal != null ? customKcal() : this.customKcal,
    macros: macros ?? this.macros,
    learnedMaintenance: learnedMaintenance != null ? learnedMaintenance() : this.learnedMaintenance,
  );

  Map<String, dynamic> toJson() => {
    'country': country,
    'metric': metric,
    'sex': sex.name,
    'age': age,
    'h': heightCm,
    'w': weightKg,
    'act': activity,
    'goal': goal.name,
    'pace': paceKg,
    'kcal': customKcal,
    'macros': macros.name,
    if (learnedMaintenance != null) 'lm': learnedMaintenance,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    country: j['country'] as String? ?? 'IN',
    metric: j['metric'] as bool? ?? true,
    sex: j['sex'] == 'female' ? Sex.female : Sex.male,
    age: j['age'] as int? ?? 25,
    heightCm: _d(j['h']),
    weightKg: _d(j['w']),
    activity: _d(j['act']),
    goal: Goal.values.firstWhere((g) => g.name == j['goal'], orElse: () => Goal.maintain),
    paceKg: _d(j['pace']),
    customKcal: j['kcal'] as int?,
    macros: MacroPreset.values.firstWhere(
      (m) => m.name == j['macros'],
      orElse: () => MacroPreset.balanced,
    ),
    learnedMaintenance: (j['lm'] as num?)?.toDouble(),
  );
}

enum Provider {
  groq('Groq', 'Recommended · generous free tier'),
  gemini('Gemini', 'Free tier is small'),
  custom('Custom', 'Ollama, LM Studio, OpenRouter');

  const Provider(this.label, this.blurb);
  final String label;
  final String blurb;
}

class AiConfig {
  const AiConfig({
    this.provider = Provider.groq,
    this.model = '',
    this.baseUrl = '',
    this.visionModel = '',
  });

  final Provider provider;
  final String model;

  /// Only for [Provider.custom], e.g. http://192.168.1.20:11434/v1
  final String baseUrl;

  /// Model used for photos when the main one can't see images.
  final String visionModel;

  bool get ready => model.isNotEmpty && (provider != Provider.custom || baseUrl.isNotEmpty);

  AiConfig copyWith({Provider? provider, String? model, String? baseUrl, String? visionModel}) =>
      AiConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        baseUrl: baseUrl ?? this.baseUrl,
        visionModel: visionModel ?? this.visionModel,
      );

  Map<String, dynamic> toJson() => {
    'p': provider.name,
    'm': model,
    'b': baseUrl,
    if (visionModel.isNotEmpty) 'v': visionModel,
  };

  factory AiConfig.fromJson(Map<String, dynamic> j) => AiConfig(
    provider: Provider.values.firstWhere((p) => p.name == j['p'], orElse: () => Provider.groq),
    model: j['m'] as String? ?? '',
    baseUrl: j['b'] as String? ?? '',
    visionModel: j['v'] as String? ?? '',
  );
}
