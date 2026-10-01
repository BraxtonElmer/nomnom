import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'countries.dart';
import 'food_db.dart';

/// Packaged products from Open Food Facts (ODbL), searched live through
/// its search service. Results
/// come back as [DbFood] so they rank and match like the bundled tables.
class OpenFoodFacts {
  static const _fields =
      'code,product_name,brands,nutriments,serving_quantity,serving_size,product_quantity';
  static final _cache = <String, List<DbFood>>{};

  /// Products sold in the user's country first, then everywhere.
  static Future<List<DbFood>> search(String terms, {String country = 'IN', int limit = 10}) async {
    final q = terms.trim().replaceAll('"', '');
    if (q.length < 2) return const [];
    final key = '$country|${q.toLowerCase()}';
    if (_cache[key] case final hit?) return hit;

    final tag = countryName(country).toLowerCase().replaceAll(' ', '-');
    final results = await Future.wait([_query('$q countries_tags:"en:$tag"'), _query(q)]);
    final seen = <String>{};
    final out = [
      for (final list in results)
        for (final f in list)
          if (seen.add(f.id)) f,
    ].take(limit).toList();
    if (out.isNotEmpty) _cache[key] = out;
    return out;
  }

  static Future<List<DbFood>> _query(String q) async {
    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': q,
      'page_size': '12',
      'fields': _fields,
    });
    try {
      final r = await http
          .get(uri, headers: kIsWeb ? null : const {'User-Agent': 'nomnom/2.1 (food logging app)'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return const [];
      return parse(utf8.decode(r.bodyBytes));
    } catch (_) {
      return const [];
    }
  }

  @visibleForTesting
  static List<DbFood> parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>?;
    final products = (j?['hits'] ?? j?['products']) as List? ?? const [];
    final out = <DbFood>[];
    for (final p in products.whereType<Map<String, dynamic>>()) {
      final n = p['nutriments'];
      if (n is! Map<String, dynamic>) continue;
      final name = (p['product_name'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final brands = p['brands'];
      final brand = (brands is List ? brands.join(',') : '${brands ?? ''}').split(',').first.trim();
      final title = brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())
          ? name
          : '$brand $name';
      double? number(Object? x) => x is num ? x.toDouble() : double.tryParse('${x ?? ''}');
      final serving = number(p['serving_quantity']);
      // Net weight of the whole pack, when the label gives it.
      final pack = number(p['product_quantity']);

      // Values are per 100 g as sold; some products also give them as
      // prepared (noodles cooked, powder mixed), which is what a bowl is.
      for (final prepared in [false, true]) {
        final tag = prepared ? '_prepared' : '';
        double? v(String k) => (n['$k${tag}_100g'] as num?)?.toDouble();
        final kcal = v('energy-kcal') ?? (v('energy') == null ? null : v('energy')! / 4.184);
        if (kcal == null || kcal <= 0) continue;
        final sodium = v('sodium') ?? (v('salt') == null ? null : v('salt')! / 2.5);
        double? mg(double? g) => g == null ? null : g * 1000;
        final micros = <Micro, double?>{
          Micro.sugar: v('sugars'),
          Micro.satFat: v('saturated-fat'),
          Micro.sodium: mg(sodium),
          Micro.potassium: mg(v('potassium')),
          Micro.calcium: mg(v('calcium')),
          Micro.iron: mg(v('iron')),
          Micro.vitaminC: mg(v('vitamin-c')),
          Micro.vitaminB12: v('vitamin-b12') == null ? null : v('vitamin-b12')! * 1e6,
        };
        final label = prepared ? '$title (as prepared)' : title;
        out.add(
          DbFood(
            id: 'off:${p['code']}${prepared ? ':prep' : ''}',
            name: label,
            source: Source.off,
            per100: Nutrients(
              kcal: kcal,
              protein: v('proteins') ?? 0,
              carbs: v('carbohydrates') ?? 0,
              fat: v('fat') ?? 0,
              fiber: v('fiber') ?? 0,
              micros: {
                for (final e in micros.entries)
                  if (e.value != null) e.key: e.value!,
              },
            ),
            portions: [
              if (!prepared && serving != null && serving > 0) ('1 serving', serving),
              if (!prepared && pack != null && pack > 0) ('1 pack', pack),
            ],
            tokens: tokenize('$label $brand'),
            head: tokenize(title),
            first: '',
            length: tokenize(title).length,
          ),
        );
      }
    }
    return out;
  }
}
