import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/pantry.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/pressable.dart';

/// The user's answer for one planned pantry use.
class StockChoice {
  /// Null until decided where a decision is needed.
  bool? take;

  /// Overrides the planned amount (raw grams, what's left…).
  double? amount;

  /// Weighed raw (false) or cooked (true), when that was the question. The
  /// amount follows the item if its quantity changes afterwards.
  bool? cooked;

  /// Remember the link ("always") or its absence ("never").
  bool always = false;
  bool never = false;
}

/// Answers are keyed by the item itself, not its position, so removing an
/// item doesn't hand its answer to the next one.
String stockKey(StockUse u, List<Object> keys) =>
    '${identityHashCode(keys[u.item])}:${u.stock.id}';

/// The amount a use takes given the answer so far.
double? choiceAmount(StockUse u, StockChoice? c) {
  if (c?.cooked != null && u.suggested != null) {
    final y = cookedYield(u.stock.name) ?? 1;
    return c!.cooked! ? (u.suggested! / y).roundToDouble() : u.suggested;
  }
  return c?.amount ?? u.amount;
}

/// When editing, what the entry already took stands as answered, so saving
/// without touching the pantry changes nothing.
void prefillStock(
  List<StockUse> plan,
  List<Object> keys,
  Map<String, StockChoice> choices,
  Map<String, double> previous,
) {
  for (final u in plan) {
    final took = previous[u.stock.id];
    if (took == null || choices.containsKey(stockKey(u, keys))) continue;
    // Only when one item uses that stock; otherwise the split is unknown.
    if (plan.where((x) => x.stock.id == u.stock.id).length != 1) continue;
    choices[stockKey(u, keys)] = StockChoice()
      ..take = true
      ..amount = took;
  }
}

/// Turns the plan and answers into what the entry takes. [open] is true
/// while a question is unanswered; those uses are left out.
/// Amounts are capped at what's on the shelf ([previous] is what an edited
/// entry already took), so undoing a meal never puts back more than it took.
({Map<String, double> use, bool open}) resolveStock(
  List<StockUse> plan,
  List<Object> keys,
  Map<String, StockChoice> choices, {
  Map<String, double> previous = const {},
}) {
  final use = <String, double>{};
  var open = false;
  for (final u in plan) {
    final c = choices[stockKey(u, keys)];
    final take = c?.take ?? (u.ask == null ? true : null);
    if (take == null) {
      open = true;
      continue;
    }
    if (!take) continue;
    final amount = choiceAmount(u, c);
    if (amount == null) {
      open = true;
      continue;
    }
    final shelf = u.stock.left + (previous[u.stock.id] ?? 0) - (use[u.stock.id] ?? 0);
    use[u.stock.id] = (use[u.stock.id] ?? 0) + amount.clamp(0, shelf < 0 ? 0 : shelf);
  }
  return (use: use, open: open);
}

/// Saves "always" and "never" answers as links on the stock items.
Future<void> rememberStockLinks(
  List<StockUse> plan,
  List<Object> keys,
  Map<String, StockChoice> choices,
  List<FoodItem> items,
) async {
  for (final u in plan) {
    final c = choices[stockKey(u, keys)];
    if (c == null || u.ask != StockAsk.link) continue;
    if (c.always && c.take == true) {
      await Store.i.linkStock(u.stock.id, items[u.item].name, yes: true);
    } else if (c.never) {
      await Store.i.linkStock(u.stock.id, items[u.item].name, yes: false);
    }
  }
}

/// "From your pantry": what this meal takes, and any question about it.
class PantrySection extends StatelessWidget {
  const PantrySection({
    super.key,
    required this.plan,
    required this.items,
    required this.keys,
    required this.choices,
    required this.onChanged,
    this.previous = const {},
  });

  final List<StockUse> plan;
  final List<FoodItem> items;
  final Map<String, StockChoice> choices;

  /// One object per item, for [stockKey].
  final List<Object> keys;
  final VoidCallback onChanged;

  /// What the entry took before an edit, back on the shelf for the preview.
  final Map<String, double> previous;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Text('FROM YOUR PANTRY', style: T.caps),
        const SizedBox(height: 4),
        for (final u in plan)
          _UseRow(
            key: ValueKey(stockKey(u, keys)),
            use: u,
            food: items[u.item],
            choice: choices.putIfAbsent(stockKey(u, keys), StockChoice.new),
            before: u.stock.left + (previous[u.stock.id] ?? 0),
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _UseRow extends StatefulWidget {
  const _UseRow({
    super.key,
    required this.use,
    required this.food,
    required this.choice,
    required this.before,
    required this.onChanged,
  });

  final StockUse use;
  final FoodItem food;
  final StockChoice choice;
  final double before;
  final VoidCallback onChanged;

  @override
  State<_UseRow> createState() => _UseRowState();
}

class _UseRowState extends State<_UseRow> {
  late final _amount = TextEditingController(
    text: widget.use.suggested == null ? '' : formatNum(widget.use.suggested!),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _set(void Function(StockChoice c) f) {
    f(widget.choice);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.use;
    final c = widget.choice;
    final s = u.stock;
    final take = c.take ?? (u.ask == null ? true : null);
    final amount = choiceAmount(u, c);
    final after = take == true && amount != null ? widget.before - amount : widget.before;
    // Weighed but not said raw or cooked: two answers, nothing to type.
    final y = cookedYield(s.name);
    final rawOrCooked = u.ask == StockAsk.amount && u.suggested != null && y != null && y < 1;
    final needsAmount =
        !rawOrCooked && (u.ask == StockAsk.amount || (u.ask == StockAsk.link && u.amount == null));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.name, style: T.bodyStrong)),
              if (take == false)
                Text('not taken', style: T.small)
              else ...[
                Text(s.amount(widget.before), style: T.small),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.arrow_forward_rounded, size: 13, color: C.ink3),
                ),
                Text(
                  s.amount(after < 0 ? 0 : after),
                  style: T.small.copyWith(
                    color: after <= 0 && take == true ? C.tomato : C.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (u.ask == null) ...[
                const SizedBox(width: 8),
                Pressable(
                  onTap: () => _set((c) => c.take = !(take ?? true)),
                  child: Icon(
                    take == false ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    size: 20,
                    color: C.ink3,
                    semanticLabel: take == false ? 'Take from pantry' : 'Don’t take from pantry',
                  ),
                ),
              ],
            ],
          ),
          if (u.note != null && amount == u.amount && !rawOrCooked) ...[
            const SizedBox(height: 2),
            Text(u.note!, style: T.small),
          ],
          if (u.ask == StockAsk.link) ...[
            const SizedBox(height: 8),
            Text('Did the ${widget.food.name.toLowerCase()} come from this?', style: T.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  'Yes',
                  on: take == true && !c.always,
                  onTap: () => _set((c) {
                    c.take = true;
                    c.always = false;
                    c.never = false;
                  }),
                ),
                _Pill(
                  'Yes, always',
                  on: take == true && c.always,
                  onTap: () => _set((c) {
                    c.take = true;
                    c.always = true;
                    c.never = false;
                  }),
                ),
                _Pill(
                  'No',
                  on: take == false && !c.never,
                  onTap: () => _set((c) {
                    c.take = false;
                    c.always = false;
                    c.never = false;
                  }),
                ),
                _Pill(
                  'Never',
                  on: take == false && c.never,
                  onTap: () => _set((c) {
                    c.take = false;
                    c.always = false;
                    c.never = true;
                  }),
                ),
              ],
            ),
          ],
          if (u.ask != StockAsk.short &&
              take == true &&
              amount != null &&
              amount > widget.before + 1e-6) ...[
            const SizedBox(height: 6),
            Text(
              'Only ${s.amount(widget.before)} in the pantry, so it goes to 0. '
              'Restock it if you bought more.',
              style: T.small.copyWith(color: C.tomato),
            ),
          ],
          if (u.ask == StockAsk.short) ...[
            const SizedBox(height: 8),
            Text('The pantry says only ${s.amount(widget.before)} left.', style: T.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill('Use what’s left', on: take == true, onTap: () => _set((c) => c.take = true)),
                _Pill('Don’t take', on: take == false, onTap: () => _set((c) => c.take = false)),
              ],
            ),
          ],
          if (rawOrCooked) ...[
            const SizedBox(height: 8),
            Text('Was the ${formatNum(u.suggested!)} g weighed raw or cooked?', style: T.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  'Raw',
                  on: take == true && c.cooked == false,
                  onTap: () => _set((c) {
                    c.take = true;
                    c.cooked = false;
                  }),
                ),
                _Pill(
                  'Cooked · ≈${formatNum((u.suggested! / y).roundToDouble())} g raw',
                  on: take == true && c.cooked == true,
                  onTap: () => _set((c) {
                    c.take = true;
                    c.cooked = true;
                  }),
                ),
                _Pill('Not from here', on: take == false, onTap: () => _set((c) => c.take = false)),
              ],
            ),
          ],
          if (needsAmount && take != false) ...[
            const SizedBox(height: 8),
            Text(
              s.counted
                  ? 'How many went in?'
                  : 'How much ${s.raw ? 'raw ' : ''}${s.name.toLowerCase()} went in?',
              style: T.body,
            ),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    style: T.body.copyWith(fontSize: 18),
                    cursorColor: C.tomato,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: s.counted ? null : s.unit,
                      suffixStyle: T.small,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: C.ink, width: 1.2),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: C.tomato, width: 1.6),
                      ),
                    ),
                    onChanged: (v) => _set((c) {
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      c.amount = n;
                      if (n != null && u.ask == StockAsk.amount) c.take = true;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                if (u.note != null) Expanded(child: Text(u.note!, style: T.small)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Motion.fast,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: on ? C.ink : null,
        border: Border.all(color: C.ink),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: T.small.copyWith(color: on ? C.paper : C.ink)),
    ),
  );
}
