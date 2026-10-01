import '../data/models.dart';
import 'food_db.dart';

/// Plain single foods that are safe to read without the AI: USDA entry,
/// the unit people use for it, and grams for each unit.
const _plain = <String, (String, String, Map<String, double>)>{
  'banana': ('usda:173944', 'piece', {'piece': 118}),
  'apple': ('usda:171688', 'piece', {'piece': 182}),
  'orange': ('usda:169097', 'piece', {'piece': 140}),
  'mango': ('usda:169910', 'piece', {'piece': 200}),
  'pear': ('usda:169118', 'piece', {'piece': 178}),
  'guava': ('usda:173044', 'piece', {'piece': 55}),
  'grape': ('usda:174683', 'cup', {'cup': 151, 'bowl': 151}),
  'papaya': ('usda:169926', 'cup', {'cup': 145, 'bowl': 145}),
  'watermelon': ('usda:167765', 'cup', {'cup': 152, 'bowl': 152, 'slice': 280}),
  'pineapple': ('usda:169124', 'cup', {'cup': 165, 'bowl': 165, 'slice': 84}),
  'strawberry': ('usda:167762', 'cup', {'cup': 152, 'bowl': 152, 'piece': 12}),
  'avocado': ('usda:171705', 'piece', {'piece': 150}),
  'date': ('usda:168191', 'piece', {'piece': 24}),
  'boiled egg': ('usda:173424', 'piece', {'piece': 50}),
  'egg boiled': ('usda:173424', 'piece', {'piece': 50}),
  'hard boiled egg': ('usda:173424', 'piece', {'piece': 50}),
  'fried egg': ('usda:173423', 'piece', {'piece': 46}),
  'milk': ('usda:171265', 'glass', {'glass': 244, 'cup': 244}),
  'whole milk': ('usda:171265', 'glass', {'glass': 244, 'cup': 244}),
  'full cream milk': ('usda:171265', 'glass', {'glass': 244, 'cup': 244}),
  'black coffee': ('usda:171890', 'cup', {'cup': 237, 'glass': 237}),
  'black tea': ('usda:173227', 'cup', {'cup': 237}),
  'orange juice': ('usda:169098', 'glass', {'glass': 248, 'cup': 248}),
  'cola': ('usda:174852', 'can', {'can': 370, 'glass': 250, 'bottle': 492}),
  'coke': ('usda:174852', 'can', {'can': 370, 'glass': 250, 'bottle': 492}),
  'bread': ('usda:174924', 'slice', {'slice': 29}),
  'white bread': ('usda:174924', 'slice', {'slice': 29}),
  'brown bread': ('usda:172688', 'slice', {'slice': 32}),
  'whole wheat bread': ('usda:172688', 'slice', {'slice': 32}),
  'toast': ('usda:174924', 'slice', {'slice': 29}),
  'butter': ('usda:173410', 'tsp', {'tsp': 5, 'tbsp': 14}),
  'sugar': ('usda:169655', 'tsp', {'tsp': 4.2, 'tbsp': 12.5}),
  'honey': ('usda:169640', 'tbsp', {'tbsp': 21, 'tsp': 7}),
  'peanut butter': ('usda:174266', 'tbsp', {'tbsp': 16, 'tsp': 5}),
  'olive oil': ('usda:171413', 'tbsp', {'tbsp': 13.5, 'tsp': 4.5}),
  'almond': ('usda:170567', 'handful', {'handful': 28, 'piece': 1.2}),
  'cashew': ('usda:170162', 'handful', {'handful': 28, 'piece': 1.6}),
  'peanut': ('usda:174262', 'handful', {'handful': 28}),
  'walnut': ('usda:170187', 'handful', {'handful': 28, 'piece': 4}),
  'cheese': ('usda:173414', 'slice', {'slice': 21}),
  'cheddar': ('usda:173414', 'slice', {'slice': 21}),
  'greek yogurt': ('usda:170894', 'cup', {'cup': 170, 'bowl': 170}),
  'cucumber': ('usda:168409', 'piece', {'piece': 300}),
  'tomato': ('usda:170457', 'piece', {'piece': 123}),
  'carrot': ('usda:170393', 'piece', {'piece': 61}),
  'boiled potato': ('usda:170438', 'piece', {'piece': 136}),
};

const _numbers = {
  'a': 1.0,
  'an': 1.0,
  'one': 1.0,
  'two': 2.0,
  'three': 3.0,
  'four': 4.0,
  'five': 5.0,
  'six': 6.0,
  'seven': 7.0,
  'eight': 8.0,
  'nine': 9.0,
  'ten': 10.0,
  'half': 0.5,
  'couple': 2.0,
  'dozen': 12.0,
  'single': 1.0,
};

const _units = {
  'g': 'g',
  'gm': 'g',
  'gms': 'g',
  'gram': 'g',
  'grams': 'g',
  'kg': 'kg',
  'ml': 'ml',
  'l': 'l',
  'litre': 'l',
  'liter': 'l',
  'bowl': 'bowl',
  'bowls': 'bowl',
  'katori': 'katori',
  'katoris': 'katori',
  'plate': 'plate',
  'plates': 'plate',
  'cup': 'cup',
  'cups': 'cup',
  'glass': 'glass',
  'glasses': 'glass',
  'piece': 'piece',
  'pieces': 'piece',
  'pc': 'piece',
  'pcs': 'piece',
  'slice': 'slice',
  'slices': 'slice',
  'tbsp': 'tbsp',
  'tablespoon': 'tbsp',
  'tablespoons': 'tbsp',
  'tsp': 'tsp',
  'teaspoon': 'tsp',
  'teaspoons': 'tsp',
  'spoon': 'tsp',
  'spoons': 'tsp',
  'handful': 'handful',
  'handfuls': 'handful',
  'can': 'can',
  'cans': 'can',
  'bottle': 'bottle',
  'bottles': 'bottle',
  'serving': 'serving',
  'servings': 'serving',
};

/// Words that make an amount a guess; those go to the AI, which can ask.
const _vague = {'some', 'few', 'little', 'lot', 'lots', 'bit', 'bunch', 'several', 'loads'};

const _modifiers = {
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

/// Reads simple meals on the phone: "2 rotis and dal", "banana", "200 ml
/// milk". Returns null the moment any part isn't a confident match, so the
/// AI handles everything else.
class LocalParser {
  LocalParser(this.db, {required this.country, required this.recall});

  final FoodDb db;
  final String country;
  final FoodItem? Function(String name) recall;

  List<FoodItem>? parse(String text) {
    var t = ' ${text.toLowerCase().replaceAll(RegExp(r'[.!;:"]'), ' ')} ';
    t = t.replaceAll(
      RegExp(r'\b(i|just|had|have|ate|eaten|having|for (breakfast|lunch|dinner|a snack|snack))\b'),
      ' ',
    );
    final chunks = t
        .split(RegExp(r',|\band\b|\bwith\b|&|\+|\bplus\b|\n'))
        .map((c) => c.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((c) => c.isNotEmpty)
        .toList();
    if (chunks.isEmpty || chunks.length > 6) return null;
    final items = <FoodItem>[];
    for (final c in chunks) {
      final item = _chunk(c);
      if (item == null) return null;
      items.add(item);
    }
    return items;
  }

  FoodItem? _chunk(String c) {
    final words = c.split(' ');
    if (words.any(_vague.contains)) return null;

    // Amount may lead ("2 bowls dal", "200g rice") or trail ("dal 1 bowl").
    double? qty;
    String? unit;
    final rest = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final glued = RegExp(r'^(\d+(?:\.\d+)?)([a-z]+)$').firstMatch(w);
      if (qty == null && glued != null && _units.containsKey(glued.group(2))) {
        qty = double.parse(glued.group(1)!);
        unit = _units[glued.group(2)];
      } else if (qty == null && RegExp(r'^\d+(\.\d+)?$').hasMatch(w)) {
        qty = double.parse(w);
      } else if (qty == null && RegExp(r'^\d+/\d+$').hasMatch(w)) {
        final p = w.split('/');
        qty = double.parse(p[0]) / double.parse(p[1]);
      } else if (qty == null && _numbers.containsKey(w) && i < words.length - 1) {
        qty = _numbers[w];
      } else if (unit == null && _units.containsKey(w) && (qty != null || rest.isEmpty)) {
        unit = _units[w];
      } else if (w == 'of' || w == 'x') {
        continue;
      } else {
        rest.add(w);
      }
    }
    if (rest.isEmpty) return null;
    qty ??= 1;
    if (unit == 'kg') {
      qty *= 1000;
      unit = 'g';
    } else if (unit == 'l') {
      qty *= 1000;
      unit = 'ml';
    }
    final name = rest.join(' ');
    return _known(name, qty, unit) ?? _plainFood(name, qty, unit) ?? _dish(name, qty, unit);
  }

  /// A food the user has confirmed before.
  FoodItem? _known(String name, double qty, String? unit) {
    final m = recall(name);
    if (m == null || m.source == Source.ai) return null;
    if (unit == null || unit == m.unit) return m.copyWith(qty: qty);
    if (unit == 'g' || unit == 'ml') return m.copyWith(qty: qty, unit: unit, unitGrams: 1);
    return null;
  }

  FoodItem? _plainFood(String name, double qty, String? unit) {
    final key = tokenize(name).difference(_modifiers);
    for (final MapEntry(key: label, value: (id, defUnit, grams)) in _plain.entries) {
      if (tokenize(label).length != key.length || !tokenize(label).containsAll(key)) continue;
      final food = db.get(id);
      if (food == null) return null;
      final u = unit ?? defUnit;
      final g = (u == 'g' || u == 'ml') ? 1.0 : grams[u];
      if (g == null) return null;
      return _item(food, _title(label), qty, u, g);
    }
    return null;
  }

  FoodItem? _dish(String name, double qty, String? unit) {
    final want = tokenize(name).difference(_modifiers);
    if (want.isEmpty) return null;
    final hits = db
        .search(name, country: country, limit: 5)
        .where(
          (f) => f.source == Source.dish && want.containsAll(f.head) && f.tokens.containsAll(want),
        )
        .toList();
    if (hits.isEmpty) return null;
    final food = hits.first;
    if (unit == 'g' || unit == 'ml') return _item(food, food.name, qty, unit!, 1);
    final u = unit ?? _defaultUnit(food);
    final g = portionGrams(food, u);
    if (g == null) return null;
    return _item(food, food.name, qty, u, g);
  }

  static String _defaultUnit(DbFood food) {
    final first = food.portions.isEmpty ? '' : food.portions.first.$1.toLowerCase();
    for (final u in [
      'piece',
      'bowl',
      'plate',
      'katori',
      'cup',
      'glass',
      'slice',
      'skewer',
      'roll',
    ]) {
      if (first.contains(u)) return u;
    }
    // "1 medium", "1 small", "1 whole" are counted in pieces.
    if (RegExp(r'\b(medium|small|large|whole)\b').hasMatch(first)) return 'piece';
    return 'serving';
  }

  FoodItem _item(DbFood f, String name, double qty, String unit, double unitGrams) => FoodItem(
    name: name,
    qty: qty,
    unit: unit,
    unitGrams: unitGrams,
    per100: f.per100,
    source: f.source,
    ref: f.id,
    refName: f.name,
  );

  static String _title(String s) => s[0].toUpperCase() + s.substring(1);
}

/// Grams in one [unit] of [food], from its own portion list.
double? portionGrams(DbFood food, String unit, {bool servingFallback = true}) {
  const words = {
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
  for (final w in words[unit] ?? [unit]) {
    for (final (label, grams) in food.portions) {
      final m = RegExp(r'^([\d.]+)\s+(.*)$').firstMatch(label.toLowerCase());
      if (m == null) continue;
      final amount = double.tryParse(m.group(1)!) ?? 1;
      if (RegExp('\\b$w').hasMatch(m.group(2)!) && amount > 0) return grams / amount;
    }
  }
  if (servingFallback && unit == 'serving' && food.portions.isNotEmpty) {
    return food.portions.first.$2;
  }
  return null;
}
