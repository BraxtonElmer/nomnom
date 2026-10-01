import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/meal_parser.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/food_db.dart';
import '../../nutrition/open_food_facts.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/nutrition_details.dart';
import '../../ui/pressable.dart';
import 'review_screen.dart';

class ItemResult {
  const ItemResult.update(FoodItem this.item) : delete = false;
  const ItemResult.remove() : item = null, delete = true;

  final FoodItem? item;
  final bool delete;
}

/// Adjust one item: amount, which food it matched, or remove it.
/// With [parsed] null it adds a new item from the food tables.
Future<ItemResult?> showItemSheet(BuildContext context, ParsedItem? parsed) =>
    showPaperSheet<ItemResult>(context, (_) => _ItemSheet(parsed: parsed));

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.parsed});

  final ParsedItem? parsed;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  FoodItem? _item;
  late final _grams = TextEditingController();
  final _query = TextEditingController();
  List<DbFood> _results = [];
  List<DbFood> _packaged = [];
  bool _packagedLoading = false;
  Timer? _debounce;
  bool _more = false;

  bool get _adding => widget.parsed == null;

  @override
  void initState() {
    super.initState();
    _item = widget.parsed?.item;
    _syncGrams();
    _results = widget.parsed?.candidates ?? const [];
    if (_results.isEmpty && _item != null) {
      _results = FoodDb.i.search(_item!.name, country: Store.i.profile.country);
    }
  }

  @override
  void dispose() {
    _grams.dispose();
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _syncGrams() {
    if (_item != null) _grams.text = _item!.grams.round().toString();
  }

  void _search(String q) {
    final country = Store.i.profile.country;
    setState(() {
      _results = q.trim().isEmpty
          ? (widget.parsed?.candidates ?? const [])
          : FoodDb.i.search(q, country: country);
      _packaged = [];
      _packagedLoading = q.trim().length >= 3;
    });
    _debounce?.cancel();
    if (q.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final hits = await OpenFoodFacts.search(q, country: country);
      if (!mounted || _query.text != q) return;
      setState(() {
        _packaged = hits;
        _packagedLoading = false;
      });
    });
  }

  /// The user typed a gram amount; re-matching keeps it.
  bool _gramsSet = false;

  void _choose(DbFood food) {
    final base =
        _item ??
        FoodItem(
          name: food.name.split(',').first,
          qty: 1,
          unit: food.portions.isEmpty ? 'g' : 'serving',
          unitGrams: food.portions.isEmpty ? 100 : food.portions.first.$2,
          per100: food.per100,
          source: food.source,
        );
    final estimate = widget.parsed?.estimate ?? base;
    setState(() {
      _item = MealParser.fromDb(
        food,
        estimate.copyWith(qty: base.qty, unit: base.unit, unitGrams: base.unitGrams),
      ).copyWith(name: _adding ? _cleanName(food.name) : base.name, flagged: false);
      if (_adding && food.portions.isEmpty) {
        _item = _item!.copyWith(qty: 100, unit: 'g', unitGrams: 1);
      } else if (_gramsSet && !base.byWeight) {
        _item = _item!.copyWith(unitGrams: base.unitGrams);
      }
      _syncGrams();
    });
  }

  String _cleanName(String s) {
    final parts = s.split(',').map((p) => p.trim()).toList();
    return parts.length > 1 && parts.first.length < 4 ? '${parts[0]} ${parts[1]}' : parts.first;
  }

  void _setGrams(String v) {
    final g = double.tryParse(v);
    if (g == null || g <= 0 || _item == null) return;
    _gramsSet = true;
    setState(
      () => _item = _item!.byWeight
          ? _item!.copyWith(qty: g)
          : _item!.copyWith(unitGrams: g / _item!.qty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.86,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.gutter, 18, S.gutter, 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(item?.name ?? 'Add an item', style: T.title),
                if (item != null) ...[
                  const SizedBox(height: 8),
                  SourceTag(item: item),
                  if (item.refName != null &&
                      item.refName!.toLowerCase() != item.name.toLowerCase()) ...[
                    const SizedBox(height: 4),
                    Text(item.refName!, style: T.small.copyWith(fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      QtyStepper(
                        label: item.qtyLabel,
                        onMinus: () => setState(() {
                          _item = item.step(-1);
                          _syncGrams();
                        }),
                        onPlus: () => setState(() {
                          _item = item.step(1);
                          _syncGrams();
                        }),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: PaperField(
                          label: item.byWeight ? 'Amount' : 'Grams in total',
                          controller: _grams,
                          keyboard: TextInputType.number,
                          formatters: [FilteringTextInputFormatter.digitsOnly],
                          suffix: item.unit == 'ml' ? 'ml' : 'g',
                          onChanged: _setGrams,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _num('kcal', item.total.kcal, C.ink),
                      _num('protein', item.total.protein, C.protein),
                      _num('carbs', item.total.carbs, C.carbs),
                      _num('fat', item.total.fat, C.fat),
                    ],
                  ),
                  if (item.source == Source.dish) ...[
                    const SizedBox(height: 22),
                    Text('OIL AND GHEE', style: T.caps),
                    const SizedBox(height: 10),
                    Segmented<int>(
                      values: const [-1, 0, 1],
                      labels: const ['Light', 'Typical', 'Rich'],
                      value: item.richness,
                      onChanged: (r) => setState(() => _item = item.copyWith(richness: r)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This is an average home recipe. Home versions differ mostly in oil and '
                      'ghee, often by 20% or more in calories, so pick what matches your kitchen. '
                      'nomnom remembers it next time.',
                      style: T.small.copyWith(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextLink(
                      label: _more ? 'Fewer nutrients' : 'More nutrients',
                      color: C.ink2,
                      onTap: () => setState(() => _more = !_more),
                    ),
                  ),
                  AnimatedSize(
                    duration: Motion.base,
                    curve: Motion.curve,
                    alignment: Alignment.topCenter,
                    child: _more
                        ? NutritionDetails(items: [item], compact: true)
                        : const SizedBox(width: double.infinity),
                  ),
                ],
                const SizedBox(height: 28),
                Text(item == null ? 'FIND A FOOD' : 'NOT RIGHT? MATCH ANOTHER FOOD', style: T.caps),
                const SizedBox(height: 4),
                TextField(
                  controller: _query,
                  onChanged: _search,
                  style: T.body.copyWith(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: 'Search foods',
                    hintStyle: T.body.copyWith(fontSize: 17, color: C.ink3),
                    prefixIcon: Icon(Icons.search_rounded, color: C.ink2, size: 20),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.ink)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: C.tomato)),
                  ),
                ),
                if (item?.aiTotal case final ai?)
                  _option(
                    title: 'Use the AI estimate instead',
                    sub: '${kcal(ai.kcal)} kcal · ${macros(ai)} for this amount',
                    selected: false,
                    onTap: () => setState(() {
                      _item = FoodItem(
                        name: item!.name,
                        qty: item.qty,
                        unit: item.unit,
                        unitGrams: item.aiUnitGrams ?? item.unitGrams,
                        per100: item.ai!,
                        source: Source.ai,
                        ai: item.ai,
                      );
                      _syncGrams();
                    }),
                  ),
                for (final f in _results)
                  _option(
                    title: f.name,
                    sub: '${f.source.label} · ${f.per100.kcal.round()} kcal per 100 g',
                    selected: f.id == item?.ref,
                    onTap: () => _choose(f),
                  ),
                if (_packagedLoading || _packaged.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('PACKAGED PRODUCTS', style: T.caps),
                      const SizedBox(width: 10),
                      if (_packagedLoading) const Dots(size: 4),
                    ],
                  ),
                  for (final f in _packaged)
                    _option(
                      title: f.name,
                      sub: 'Open Food Facts · ${f.per100.kcal.round()} kcal per 100 g',
                      selected: f.id == item?.ref,
                      onTap: () => _choose(f),
                    ),
                ],
                if (_results.isEmpty &&
                    _packaged.isEmpty &&
                    !_packagedLoading &&
                    _query.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Nothing found for that.', style: T.small),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (!_adding) ...[
                  Pressable(
                    onTap: () => Navigator.pop(context, const ItemResult.remove()),
                    semanticLabel: 'Remove item',
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: C.tomato),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: C.tomato),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: _adding ? 'Add item' : 'Done',
                    onTap: item == null
                        ? null
                        : () => Navigator.pop(context, ItemResult.update(item)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _num(String label, double v, Color c) => Column(
    children: [
      Text(
        label == 'kcal' ? kcal(v) : '${formatNum((v * 10).round() / 10)}g',
        style: T.heading.copyWith(color: c == C.ink ? C.ink : c),
      ),
      Text(label.toUpperCase(), style: T.caps),
    ],
  );

  Widget _option({
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) => Pressable(
    onTap: onTap,
    scale: 0.99,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(color: selected ? C.tomato : C.ink)),
                const SizedBox(height: 2),
                Text(sub, style: T.small.copyWith(fontSize: 12)),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_rounded, color: C.tomato, size: 20),
        ],
      ),
    ),
  );
}
