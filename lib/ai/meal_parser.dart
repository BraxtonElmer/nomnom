import '../data/keys.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../nutrition/countries.dart';
import '../nutrition/food_db.dart';
import 'client.dart';

/// One parsed food plus everything needed to change our mind about it on
/// the review screen without another round trip.
class ParsedItem {
  ParsedItem({required this.item, required this.estimate, required this.candidates});

  FoodItem item;

  /// The model's own numbers, kept as a fallback choice.
  final FoodItem estimate;
  final List<DbFood> candidates;
}

class ParsedMeal {
  ParsedMeal({required this.title, required this.meal, required this.items, this.note});

  final String title;
  final Meal? meal;
  final List<ParsedItem> items;

  /// One helpful line about the plate, from the model.
  final String? note;
}

/// Text → items in two steps. The model reads the sentence; the numbers come
/// from the bundled tables whenever there's a match.
class MealParser {
  MealParser(this.client, {required this.country, FoodItem? Function(String name)? recall})
    : recall = recall ?? Store.i.recall;

  final AiClient client;
  final String country;

  /// Previously confirmed version of a food, if any.
  final FoodItem? Function(String name) recall;

  static Future<MealParser> fromSettings() async {
    final s = Store.i;
    await FoodDb.load();
    final key = await KeyVault.read(s.ai.provider);
    if (!s.ai.ready || (key.isEmpty && s.ai.provider != Provider.custom)) {
      throw const AiException('Connect an AI model in You → AI model first.');
    }
    return MealParser(AiClient.of(s.ai, key), country: s.profile.country);
  }

  Future<ParsedMeal> parse(String text) async {
    final raw = await client.json(_parseSystem(countryName(country)), text.trim());
    final rawItems = (raw['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((m) => (m['name'] as String?)?.trim().isNotEmpty ?? false)
        .toList();
    if (rawItems.isEmpty) {
      throw const AiException(
        "Didn't catch any food in that. Try something like “2 eggs and toast”.",
      );
    }

    final parsed = <ParsedItem>[];
    final unresolved = <int>[];
    for (final r in rawItems) {
      final estimate = _estimate(r);
      final remembered = recall(estimate.name);
      if (remembered != null) {
        parsed.add(
          ParsedItem(item: _adopt(remembered, estimate), estimate: estimate, candidates: const []),
        );
        continue;
      }
      final query = (r['search'] as String?)?.trim();
      final candidates = FoodDb.i.search(
        (query == null || query.isEmpty) ? estimate.name : query,
        country: country,
      );
      parsed.add(ParsedItem(item: estimate, estimate: estimate, candidates: candidates));
      if (candidates.isNotEmpty) unresolved.add(parsed.length - 1);
    }

    if (unresolved.isNotEmpty) {
      final ids = await _resolve(parsed, unresolved, rawItems);
      for (final i in unresolved) {
        final id = ids[i];
        final food =
            parsed[i].candidates.where((c) => c.id == id).firstOrNull ?? FoodDb.i.get(id);
        if (food != null) parsed[i].item = fromDb(food, parsed[i].estimate);
      }
    }

    final title = (raw['title'] as String?)?.trim();
    return ParsedMeal(
      title: (title == null || title.isEmpty) ? _fallbackTitle(parsed) : title,
      meal: raw['meal'] == null
          ? null
          : Meal.values.where((m) => m.name == raw['meal']).firstOrNull,
      items: parsed,
      note: (raw['note'] as String?)?.trim().nullIfEmpty,
    );
  }

  Future<Map<int, String?>> _resolve(
    List<ParsedItem> parsed,
    List<int> which,
    List<Map<String, dynamic>> raw,
  ) async {
    final b = StringBuffer();
    for (final i in which) {
      final p = parsed[i];
      b.writeln(
        '$i. ${p.estimate.name} (${p.estimate.qtyLabel}; search: ${raw[i]['search'] ?? ''})',
      );
      for (final c in p.candidates) {
        b.writeln('   - ${c.id} | ${c.name} | ${c.per100.kcal.round()} kcal/100g');
      }
    }
    try {
      final res = await client.json(_resolveSystem, b.toString());
      final out = <int, String?>{};
      for (final m in (res['matches'] as List? ?? const [])) {
        if (m is! Map) continue;
        final i = (m['item'] as num?)?.toInt();
        if (i != null && which.contains(i)) out[i] = m['id'] as String?;
      }
      return out;
    } on AiException {
      // Matching is a refinement; if it fails the estimates still stand.
      return {};
    }
  }

  /// The model's estimate as an item, normalised to per-100 g.
  static FoodItem _estimate(Map<String, dynamic> r) {
    double n(String k) => (r[k] as num?)?.toDouble() ?? 0;
    var qty = n('qty');
    if (qty <= 0) qty = 1;
    final rawUnit = (r['unit'] as String? ?? '').toLowerCase().trim();
    if (const {'kg', 'l', 'litre', 'liter'}.contains(rawUnit)) qty *= 1000;
    final unit = _unit(r['unit'] as String?);
    var grams = n('grams');
    if (unit == 'g' || unit == 'ml') grams = qty;
    if (grams <= 0) grams = qty * 100;
    final f = 100 / grams;
    return FoodItem(
      name: _cap((r['name'] as String).trim()),
      qty: qty,
      unit: unit,
      unitGrams: (unit == 'g' || unit == 'ml') ? 1 : grams / qty,
      per100: Nutrients(
        kcal: n('kcal') * f,
        protein: n('protein') * f,
        carbs: n('carbs') * f,
        fat: n('fat') * f,
        fiber: n('fiber') * f,
        micros: {
          for (final (m, key) in _microKeys)
            if (r[key] is num) m: n(key) * f,
        },
      ),
      source: Source.ai,
    );
  }

  /// Database numbers, the user's amount. Household units take the table's
  /// own portion weight when it has one, else the model's gram estimate.
  static FoodItem fromDb(DbFood food, FoodItem estimate) {
    var unitGrams = estimate.unitGrams;
    if (!estimate.byWeight) {
      final portion = _portionFor(food, estimate.unit);
      if (portion != null) unitGrams = portion;
    }
    final item = estimate.copyWith(
      unitGrams: unitGrams,
      // Tables without micronutrients borrow the model's estimate for them.
      per100: food.per100.micros.isEmpty
          ? food.per100.withMicros(estimate.per100.micros)
          : food.per100,
      source: food.source,
      ref: food.id,
      refName: food.name,
    );
    final ratio = estimate.total.kcal <= 0 ? 1 : item.total.kcal / estimate.total.kcal;
    return item.copyWith(flagged: estimate.total.kcal > 40 && (ratio > 2 || ratio < 0.5));
  }

  /// Applies a remembered food to a new amount.
  static FoodItem _adopt(FoodItem remembered, FoodItem estimate) {
    if (remembered.unit == estimate.unit) return remembered.copyWith(qty: estimate.qty);
    if (estimate.byWeight) {
      return remembered.copyWith(qty: estimate.qty, unit: estimate.unit, unitGrams: 1);
    }
    return remembered.copyWith(
      qty: estimate.qty,
      unit: estimate.unit,
      unitGrams: estimate.unitGrams,
    );
  }

  static double? _portionFor(DbFood food, String unit) {
    final words = _unitWords[unit] ?? [unit];
    for (final w in words) {
      for (final (label, grams) in food.portions) {
        final l = label.toLowerCase();
        final m = RegExp(r'^([\d.]+)\s+(.*)$').firstMatch(l);
        if (m == null) continue;
        final amount = double.tryParse(m.group(1)!) ?? 1;
        final rest = m.group(2)!;
        if (RegExp('\\b$w').hasMatch(rest) && amount > 0) return grams / amount;
      }
    }
    return null;
  }

  static const _unitWords = {
    'piece': ['piece', 'medium', 'whole', 'small', 'large', 'unit', 'item', 'roll', 'egg'],
    'slice': ['slice'],
    'cup': ['cup'],
    'bowl': ['bowl', 'katori', 'cup'],
    'katori': ['katori', 'bowl', 'cup'],
    'plate': ['plate', 'serving'],
    'glass': ['glass', 'cup'],
    'tbsp': ['tbsp', 'tablespoon'],
    'tsp': ['tsp', 'teaspoon'],
    'serving': ['serving', 'plate'],
  };

  static String _unit(String? u) {
    final s = (u ?? '').toLowerCase().trim();
    const alias = {
      'gram': 'g',
      'grams': 'g',
      'gm': 'g',
      'gms': 'g',
      'milliliter': 'ml',
      'millilitre': 'ml',
      'mls': 'ml',
      'pc': 'piece',
      'pcs': 'piece',
      'pieces': 'piece',
      'nos': 'piece',
      'whole': 'piece',
      'slices': 'slice',
      'cups': 'cup',
      'bowls': 'bowl',
      'plates': 'plate',
      'glasses': 'glass',
      'tablespoon': 'tbsp',
      'teaspoon': 'tsp',
      'servings': 'serving',
      'kg': 'g',
      'l': 'ml',
      'litre': 'ml',
      'liter': 'ml',
      '': 'serving',
    };
    return alias[s] ?? s;
  }

  static const _microKeys = [
    (Micro.sugar, 'sugar_g'),
    (Micro.satFat, 'sat_fat_g'),
    (Micro.sodium, 'sodium_mg'),
    (Micro.potassium, 'potassium_mg'),
    (Micro.calcium, 'calcium_mg'),
    (Micro.iron, 'iron_mg'),
    (Micro.vitaminC, 'vitamin_c_mg'),
    (Micro.vitaminB12, 'vitamin_b12_mcg'),
  ];

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _fallbackTitle(List<ParsedItem> items) =>
      items.map((p) => p.item.name).take(3).join(', ');
}

String _parseSystem(String country) =>
    '''
You turn a food diary line into structured data for a calorie tracker.
The user lives in $country. Assume dishes, recipes and portion sizes typical there unless the text says otherwise.

Reply with JSON only, shaped like:
{"title": "Grilled chicken, 2 rotis, dal", "meal": null, "items": [
  {"name": "Grilled chicken breast", "qty": 120, "unit": "g", "grams": 120,
   "search": "chicken breast cooked roasted",
   "kcal": 198, "protein": 37, "carbs": 0, "fat": 4.3, "fiber": 0,
   "sugar_g": 0, "sat_fat_g": 1.2, "sodium_mg": 90, "potassium_mg": 300, "calcium_mg": 18,
   "iron_mg": 1.2, "vitamin_c_mg": 0, "vitamin_b12_mcg": 0.4}
], "note": "Lean protein with fibre-rich dal; a balanced plate."}

Fields:
- title: short summary of the plate, at most 40 characters.
- meal: "breakfast", "lunch", "snack" or "dinner" only if the text says so, else null.
- name: short natural name, singular, capitalised.
- qty and unit: the amount as the user said it. unit is one of g, ml, piece, slice, cup, bowl, katori, plate, glass, tbsp, tsp, scoop, serving.
- grams: total edible grams for that amount (ml counts as grams for drinks).
- search: plain generic English words to find the food in a nutrition database like USDA, including the cooking method or state (cooked, raw, fried, boiled). Use the local dish name for regional dishes.
- kcal, protein, carbs, fat, fiber: your best estimate for the whole amount, in kcal and grams.
- sugar_g, sat_fat_g, sodium_mg, potassium_mg, calcium_mg, iron_mg, vitamin_c_mg, vitamin_b12_mcg: estimates for the whole amount, including salt and sugar normally used in the dish.
- note: one short, specific, friendly sentence about the plate's nutrition. No moralising.

Rules:
- One item per distinct food. Split combinations ("dal rice" is dal and rice). Keep a single named dish as one item ("chicken biryani", "masala dosa").
- "a", "an", "one" mean 1; "a couple" means 2; "half" means 0.5. With no amount, assume one typical serving.
- Don't add oil, ghee, sugar or sides the user didn't mention, beyond what the dish normally contains.
- If there's no food in the text, return "items": [].''';

const _resolveSystem = '''
You match foods to nutrition database entries.
For each numbered food, pick the candidate id that is the same food in the same state: cooked vs raw, with or without skin, sweetened or not, homemade vs restaurant. Prefer plain generic entries over branded ones.
If no candidate is a reasonable match, use null. Never invent ids.
Reply with JSON only: {"matches": [{"item": 0, "id": "usda:171477"}, {"item": 1, "id": null}]}''';

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
