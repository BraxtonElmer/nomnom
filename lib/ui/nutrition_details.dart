import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/tokens.dart';
import 'controls.dart';
import 'format.dart';

/// Opens the full breakdown for a set of items: the big four first, then
/// fibre and micronutrients against daily values.
Future<void> showNutritionDetails(BuildContext context, String title, List<FoodItem> items) =>
    showPaperSheet<void>(
      context,
      (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(S.gutter, 18, S.gutter, 28),
          children: [
            Text(title, style: T.title),
            const SizedBox(height: 18),
            NutritionDetails(items: items),
          ],
        ),
      ),
    );

class NutritionDetails extends StatelessWidget {
  const NutritionDetails({super.key, required this.items, this.compact = false});

  final List<FoodItem> items;

  /// Inline variant without the headline numbers.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(Nutrients.zero, (s, i) => s + i.total);
    final estimated = items.any((i) => i.source != Source.usda && i.per100.micros.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _big(kcal(total.kcal), 'kcal', C.ink),
              _big('${total.protein.round()}g', 'protein', C.protein),
              _big('${total.carbs.round()}g', 'carbs', C.carbs),
              _big('${total.fat.round()}g', 'fat', C.fat),
            ],
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: C.ink),
        ],
        _Row(label: 'Fibre', value: total.fiber, unit: 'g', dv: 28, missing: 0, of: items.length),
        for (final m in Micro.values)
          _Row(
            label: m.label,
            value: total.micros[m],
            unit: m.unit,
            dv: m.dv,
            limit: m.limit,
            missing: items.where((i) => !i.per100.micros.containsKey(m)).length,
            of: items.length,
          ),
        const SizedBox(height: 14),
        Text(
          '% of daily value for an average adult. Sugar, saturated fat and sodium are limits '
          'to stay under.${estimated ? ' Dish-table and AI items use estimated micronutrients.' : ''}',
          style: T.small.copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Widget _big(String v, String label, Color c) => Column(
    children: [
      Text(v, style: T.heading.copyWith(color: c, fontSize: 28)),
      Text(label.toUpperCase(), style: T.caps),
    ],
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.unit,
    required this.dv,
    required this.missing,
    required this.of,
    this.limit = false,
  });

  final String label;
  final double? value;
  final String unit;
  final double dv;
  final bool limit;
  final int missing;
  final int of;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final pct = v == null ? 0.0 : v / dv;
    final over = limit && pct > 1;
    final color = over ? C.tomato : (limit ? C.ink2 : C.fat);
    final amount = v == null
        ? '—'
        : unit == 'g'
        ? '${formatNum((v * 10).round() / 10)} g'
        : unit == 'mcg'
        ? '${formatNum((v * 10).round() / 10)} mcg'
        : '${kcal(v)} mg';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: T.body)),
              if (missing > 0 && v != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('partial', style: T.small.copyWith(fontSize: 11, color: C.ink3)),
                ),
              Text(amount, style: T.bodyStrong),
              SizedBox(
                width: 54,
                child: Text(
                  v == null ? '' : '${(pct * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: T.small.copyWith(color: over ? C.tomato : C.ink2),
                ),
              ),
            ],
          ),
          if (v != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 3,
              color: C.line,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
