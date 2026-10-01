import '../data/keys.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../nutrition/countries.dart';
import '../nutrition/food_db.dart';
import '../nutrition/local_parser.dart';
import '../nutrition/open_food_facts.dart';
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
  ParsedMeal({
    required this.title,
    required this.meal,
    required this.items,
    this.question,
    this.options = const [],
    this.local = false,
  });

  final String title;
  final Meal? meal;
  final List<ParsedItem> items;

  /// Asked only when a missing amount would swing the numbers a lot.
  final String? question;
  final List<String> options;

  /// Read on the phone without the AI.
  final bool local;
}

/// Text → items in two steps. The model reads the sentence; the numbers come
/// from the bundled tables whenever there's a match.
class MealParser {
  MealParser(
    this.client, {
    required this.country,
    FoodItem? Function(String name)? recall,
    this.aiOnly = false,
    AiClient? visionClient,
    Future<List<DbFood>> Function(String terms, String country)? packaged,
  }) : _vision = visionClient,
       recall = recall ?? Store.i.recall,
       packaged = packaged ?? ((t, c) => OpenFoodFacts.search(t, country: c));

  final AiClient client;
  final AiClient? _vision;
  final String country;

  /// Use the model's numbers for everything; skip the food tables.
  final bool aiOnly;

  /// Reads photos; the main client unless that model can't see images.
  late final AiClient vision = _vision ?? client;

  /// Previously confirmed version of a food, if any.
  final FoodItem? Function(String name) recall;

  /// Live packaged-food search, used when the text names a brand.
  final Future<List<DbFood>> Function(String terms, String country) packaged;

  /// Simple meals read on the phone: no request, works offline. Null when
  /// any part needs the AI. Off in AI-only mode.
  static Future<ParsedMeal?> readLocally(String text) async {
    final s = Store.i;
    if (s.aiOnly) return null;
    final db = await FoodDb.load();
    final items = LocalParser(db, country: s.profile.country, recall: s.recall).parse(text);
    if (items == null) return null;
    return ParsedMeal(
      title: _cap(items.map(_short).take(3).join(', ').toLowerCase()),
      meal: null,
      local: true,
      items: [
        for (final i in items)
          ParsedItem(
            item: i,
            estimate: i,
            candidates: db.search(i.name, country: s.profile.country),
          ),
      ],
    );
  }

  /// "2 rotis", "dal", "200 g rice": how people would write it.
  static String _short(FoodItem i) {
    if (i.byWeight) return '${formatNum(i.qty)} ${i.unit} ${i.name}';
    if (i.qty == 1 || i.unit != 'piece') return i.name;
    return '${formatNum(i.qty)} ${i.name.endsWith('s') ? i.name : '${i.name}s'}';
  }

  static Future<MealParser> fromSettings() async {
    final s = Store.i;
    await FoodDb.load();
    final key = await KeyVault.read(s.ai.provider);
    if (!s.ai.ready || (key.isEmpty && s.ai.provider != Provider.custom)) {
      throw const AiException('Connect an AI model in You → AI model first.');
    }
    return MealParser(
      AiClient.of(s.ai, key),
      country: s.profile.country,
      aiOnly: s.aiOnly,
      visionClient: AiClient.of(s.ai, key, model: visionModel(s.ai)),
    );
  }

  /// [photo] switches to reading a picture of the plate; [text] is then an
  /// optional caption.
  Future<ParsedMeal> parse(String text, {Photo? photo}) async {
    final raw = photo == null
        ? await client.json(_parseSystem(countryName(country)), text.trim())
        : await vision.json(
            '${_parseSystem(countryName(country))}\n\n$_photoRules',
            text.trim().isEmpty ? 'What is on this plate?' : 'Caption: ${text.trim()}',
            photo: photo,
          );
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
      if (aiOnly) {
        parsed.add(ParsedItem(item: estimate, estimate: estimate, candidates: const []));
        continue;
      }
      final brand = (r['brand'] as String?)?.trim() ?? '';
      final query = (r['search'] as String?)?.trim();
      final remembered = brand.isEmpty ? recall(estimate.name) : null;
      if (remembered != null && _sameState(remembered, '${estimate.name} ${query ?? ''}')) {
        parsed.add(
          ParsedItem(item: _adopt(remembered, estimate), estimate: estimate, candidates: const []),
        );
        continue;
      }
      final local = FoodDb.i.search(
        (query == null || query.isEmpty) ? estimate.name : query,
        country: country,
      );
      final candidates = brand.isEmpty
          ? local
          : [
              ...(await packaged(
                estimate.name.toLowerCase().contains(brand.toLowerCase())
                    ? estimate.name
                    : '$brand ${estimate.name}',
                country,
              )).take(6),
              ...local.take(4),
            ];
      final obvious = brand.isEmpty && _state('${estimate.name} ${query ?? ''}') != 'raw'
          ? _obviousDish(estimate, [
              ...FoodDb.i.search(estimate.name, country: country, limit: 3),
              ...local,
            ])
          : null;
      parsed.add(
        ParsedItem(
          item: obvious == null ? estimate : fromDb(obvious, estimate),
          estimate: estimate,
          candidates: candidates,
        ),
      );
      if (obvious == null && candidates.isNotEmpty) unresolved.add(parsed.length - 1);
    }

    if (unresolved.isNotEmpty) {
      final ids = await _resolve(parsed, unresolved, rawItems);
      for (final i in unresolved) {
        final id = ids[i];
        final food = parsed[i].candidates.where((c) => c.id == id).firstOrNull ?? FoodDb.i.get(id);
        if (food != null) parsed[i].item = fromDb(food, parsed[i].estimate);
      }
    }

    final title = (raw['title'] as String?)?.trim();
    final ask = raw['ask'] is Map ? raw['ask'] as Map : null;
    final options = [
      for (final o in (ask?['options'] as List? ?? const []))
        if (o is String && o.trim().isNotEmpty) o.trim(),
    ].take(4).toList();
    return ParsedMeal(
      title: (title == null || title.isEmpty) ? _fallbackTitle(parsed) : title,
      meal: raw['meal'] == null
          ? null
          : Meal.values.where((m) => m.name == raw['meal']).firstOrNull,
      items: parsed,
      question: options.length >= 2 ? (ask?['question'] as String?)?.trim().nullIfEmpty : null,
      options: options,
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
      final res = await client.json(_resolveSystem(countryName(country)), b.toString());
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

  /// A dish-table entry that is plainly what the user wrote ("poha", "dal
  /// tadka", "white rice") needs no second request to confirm. Saves quota.
  static DbFood? _obviousDish(FoodItem estimate, List<DbFood> local) {
    final want = tokenize(estimate.name);
    for (final f in local.take(3)) {
      // Its core name is in what was typed, and every typed word is one of
      // its names: "white rice" is Rice, but "egg" is not Egg curry.
      final words = want.difference(_modifiers);
      if (f.source == Source.dish && words.containsAll(f.head) && f.tokens.containsAll(words)) {
        // A very different energy density means it isn't the same thing
        // (dry dal vs cooked dal); let the matching request decide.
        final a = estimate.per100.kcal;
        final b = f.per100.kcal;
        if (a > 0 && b > 0 && (a / b > 2 || b / a > 2)) return null;
        return f;
      }
    }
    return null;
  }

  /// The model's estimate as an item, normalised to per-100 g.
  static FoodItem _estimate(Map<String, dynamic> r) {
    double n(String k) => (r[k] as num?)?.toDouble() ?? 0;
    var qty = n('qty');
    if (qty <= 0) qty = 1;
    final rawUnit = (r['unit'] as String? ?? '').toLowerCase().trim();
    if (const {'kg', 'l', 'litre', 'liter'}.contains(rawUnit)) qty *= 1000;
    final unit = _unit(r['unit'] as String?);
    final size = (unit == 'g' || unit == 'ml') ? 1.0 : sizeFactor(r['size'] as String?);
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
      size: size,
    );
  }

  /// Database numbers, the user's amount. Household units take the table's
  /// own portion weight when it has one, else the model's gram estimate.
  static FoodItem fromDb(DbFood food, FoodItem estimate) {
    var unitGrams = estimate.unitGrams;
    if (estimate.unit == 'ml') {
      unitGrams = mlDensity(food.name);
    } else if (!estimate.byWeight) {
      final portion = portionGrams(
        food,
        estimate.unit,
        servingFallback: false,
        size: estimate.size,
      );
      if (portion != null) {
        unitGrams = portion;
      } else if (estimate.unit == 'serving') {
        // "A serving" is vague both ways: trust the model's grams, which know
        // the context (takeaway, country), but keep them near a real serving:
        // a dish table's portion, or a USDA label that is one serving.
        final std = food.source == Source.dish
            ? portionGrams(food, 'serving', size: estimate.size)
            : _servingLabel(food);
        if (std != null) unitGrams = estimate.unitGrams.clamp(std * 0.6, std * 1.25);
      }
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
      ai: estimate.per100,
    );
    final ratio = estimate.total.kcal <= 0 ? 1 : item.total.kcal / estimate.total.kcal;
    return item.copyWith(flagged: estimate.total.kcal > 40 && (ratio > 2 || ratio < 0.5));
  }

  /// Applies a remembered food to a new amount.
  static FoodItem _adopt(FoodItem remembered, FoodItem estimate) {
    if (remembered.unit == estimate.unit) {
      return remembered.copyWith(
        qty: estimate.qty,
        size: estimate.size,
        unitGrams: remembered.unitGrams / remembered.size * estimate.size,
      );
    }
    if (estimate.byWeight) {
      return remembered.copyWith(qty: estimate.qty, unit: estimate.unit, unitGrams: 1);
    }
    return remembered.copyWith(
      qty: estimate.qty,
      unit: estimate.unit,
      unitGrams: estimate.unitGrams,
    );
  }

  /// Grams in one USDA serving, from a label that says so.
  static double? _servingLabel(DbFood food) {
    for (final (label, grams) in food.portions) {
      final m = RegExp(r'^([\d.]+)\s+(.*)$').firstMatch(label.toLowerCase());
      if (m != null && RegExp(r'^(serving|nlea serving)').hasMatch(m.group(2)!)) {
        return grams / (double.tryParse(m.group(1)!) ?? 1);
      }
    }
    return null;
  }

  /// 'raw' for raw, uncooked or dry foods, 'cooked' for prepared ones, else
  /// null when the words don't say.
  static String? _state(String text) {
    final t = text.toLowerCase();
    if (RegExp(r'\b(raw|uncooked|dry|dried|unprepared)\b').hasMatch(t)) return 'raw';
    if (RegExp(
      r'\b(cooked|boiled|fried|roasted|grilled|baked|steamed|stewed|prepared)\b',
    ).hasMatch(t)) {
      return 'cooked';
    }
    return null;
  }

  /// A remembered food fits this one unless they plainly differ in state
  /// (a remembered cooked rice for "100 g uncooked rice").
  static bool _sameState(FoodItem remembered, String text) {
    final want = _state(text);
    if (want == null) return true;
    final have = remembered.source == Source.dish
        ? 'cooked'
        : _state('${remembered.refName ?? ''} ${remembered.name}');
    return have == null || have == want;
  }

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

  /// Words that describe a dish without changing what it is.
  static const _modifiers = {
    'veg',
    'vegetable',
    'plain',
    'homemade',
    'home',
    'made',
    'fresh',
    'hot',
    'spicy',
    'small',
    'medium',
    'large',
    'big',
    'extra',
    'restaurant',
    'takeaway',
    'style',
  };

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
The user lives in $country. People eat food from every cuisine, at home and out: Chinese takeaway in India, curry in London, sushi anywhere.
- Identify each dish by its own cuisine and recipe, whatever the country.
- For portions, use what is typical where the user lives; use restaurant or takeaway portions when the food sounds ordered or eaten out.

Reply with JSON only, shaped like:
{"title": "Grilled chicken, 2 rotis, dal", "meal": null, "items": [
  {"name": "Grilled chicken breast", "qty": 120, "unit": "g", "grams": 120,
   "search": "chicken breast cooked roasted", "brand": null,
   "kcal": 198, "protein": 37, "carbs": 0, "fat": 4.3, "fiber": 0,
   "sugar_g": 0, "sat_fat_g": 1.2, "sodium_mg": 90, "potassium_mg": 300, "calcium_mg": 18,
   "iron_mg": 1.2, "vitamin_c_mg": 0, "vitamin_b12_mcg": 0.4}
], "ask": null}

Fields:
- title: short summary of the plate, at most 40 characters.
- meal: "breakfast", "lunch", "snack" or "dinner" only if the text says so, else null.
- name: short natural name, singular, capitalised.
- qty and unit: the amount as the user said it. unit is one of g, ml, piece, slice, cup, bowl, katori, plate, glass, tbsp, tsp, scoop, serving.
- grams: total edible grams for that amount (ml counts as grams for drinks).
- size: "small", "large" or "extra large" when the user said a size word, else null.
- brand: the brand if the user named a packaged product ("Amul", "Maggi", "Coca-Cola", "Quest"), else null.
- search: plain generic English words to find the food in a nutrition database like USDA, including the cooking method or state (cooked, raw, fried, boiled). Use the local dish name for regional dishes.
- kcal, protein, carbs, fat, fiber: your best estimate for the whole amount, in kcal and grams.
- sugar_g, sat_fat_g, sodium_mg, potassium_mg, calcium_mg, iron_mg, vitamin_c_mg, vitamin_b12_mcg: estimates for the whole amount, including salt and sugar normally used in the dish.
- ask: usually null. Only when the text gives no amount for a food whose typical portion varies a lot in calories (rice, curry, pasta, biryani, "some", "a lot"), return {"question": "How much rice?", "options": ["Small bowl", "1 cup", "Full plate"]}: one short question, 2 to 4 short options in everyday portion words. Still fill items with your best guess.

Rules:
- One item per distinct food. Split combinations ("dal rice" is dal and rice). Keep a single named dish as one item ("chicken biryani", "masala dosa").
- When the user gives a home dish by its ingredients and amounts ("3 egg omelette with 1 tsp butter", "40 g oats cooked in 200 ml milk"), list those ingredients as items (3 eggs, 1 tsp butter) instead of the dish: their numbers are exact, a recipe's are not. Search for each ingredient as it was before cooking ("egg whole raw"), since the fat is its own item; keep the name plain ("Egg").
- "a", "an", "one" mean 1; "a couple" means 2; "half" means 0.5. With no amount, assume one typical serving.
- Size words never change qty or unit: put them in "size" ("small", "large" or "extra large"; null otherwise). "2 large eggs" is qty 2, unit piece, size "large". grams is still the total for that size.
- A line starting "Portion answer:" is the user answering a question about amounts. Apply it to the foods it names, then return "ask": null.
- Don't add oil, ghee, sugar or sides the user didn't mention, beyond what the dish normally contains.
- If there's no food in the text, return "items": [].''';

String _resolveSystem(String country) =>
    '''
You match foods to nutrition database entries for someone in $country.
For each numbered food, pick the candidate id that best matches the food as eaten: same food, same state (cooked vs raw, with or without skin, sweetened or not).
- Ids like "in-…", "cn-…", "jp-…", "it-…" are dish tables of typical recipes for each cuisine (in = Indian home-style, cn = Chinese, jp = Japanese, it = Italian, and so on). Prefer them for prepared dishes; prefer USDA for single ingredients and plain foods.
- Regional names: full cream milk is whole milk, toned milk is 2% milk, curd is plain yogurt, brown bread is whole-wheat bread.
- Close variants are fine when nothing is exact: plain "dal" can match dal tadka or dal fry; "curd" can match plain yogurt.
- Ids starting with "off:" are packaged products; pick one only when the user named that brand or product.
- Prefer plain generic entries over branded ones otherwise.
- If no candidate is a reasonable match, use null. Never invent ids.
Reply with JSON only: {"matches": [{"item": 0, "id": "usda:171477"}, {"item": 1, "id": null}]}''';

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

const _photoRules = '''
The user sent a photo of their food instead of typing.
- Identify every food you can see. Estimate amounts from visual cues: a dinner plate is about 26 cm across, a katori or small bowl holds about 150 g, a spoon about 15 g.
- If a caption is given, it wins over what you see ("half of this" means half of the plate).
- If the photo isn't food, return "items": [].
- Only ask a question when an amount truly can't be judged from the photo.''';
