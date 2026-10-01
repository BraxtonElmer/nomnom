import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/pantry.dart';
import '../../data/reminders.dart';
import '../../data/store.dart';
import '../../nutrition/food_db.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/pressable.dart';
import '../log/review_screen.dart';

/// Food at home, counted down as meals are logged.
class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final stock = s.stock;
        final checks = s.stockChecks;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(S.gutter, 12, S.gutter, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text('Pantry', style: T.title)),
                  TextLink(label: '+ Add', onTap: () => addStock(context)),
                ],
              ),
              const SizedBox(height: 6),
              Text('What you have at home. It goes down as you log meals.', style: T.small),
              if (checks.isNotEmpty) ...[const SizedBox(height: 20), _Checks(entries: checks)],
              const SizedBox(height: 18),
              if (stock.isEmpty)
                _Empty(onAdd: () => addStock(context))
              else ...[
                for (final (i, item) in stock.indexed)
                  _StockRow(
                    item: item,
                    last: i == stock.length - 1,
                    onTap: () => showPaperSheet(context, (_) => _StockSheet(id: item.id)),
                  ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pantry alerts', style: T.body),
                          Text('Running low, run out, use-by dates', style: T.small),
                        ],
                      ),
                    ),
                    PaperSwitch(
                      label: 'Pantry alerts',
                      value: s.stockAlerts,
                      onChanged: (v) async {
                        if (v && !await Reminders.askPermission()) {
                          if (context.mounted) {
                            showToast(context, 'Notifications are off for nomnom in settings.');
                          }
                          return;
                        }
                        await s.setStockAlerts(v);
                      },
                    ),
                  ],
                ),
                if (s.stockAlerts) ...[
                  const SizedBox(height: 8),
                  RuledRow(
                    label: 'Low for counted things',
                    value: '${formatNum(StockItem.lowPieces)} left',
                    onTap: () async {
                      final v = await _askNumber(
                        context,
                        'Warn when down to',
                        StockItem.lowPieces,
                        'left',
                      );
                      if (v != null) await s.setLowDefaults(pieces: v);
                    },
                  ),
                  RuledRow(
                    label: 'Low for weighed things',
                    value: '${formatNum(StockItem.lowPercent)}% left',
                    onTap: () async {
                      final v = await _askNumber(
                        context,
                        'Warn at this much of the last restock',
                        StockItem.lowPercent,
                        '%',
                      );
                      if (v != null && v <= 100) await s.setLowDefaults(percent: v);
                    },
                  ),
                  RuledRow(
                    label: 'Use-by alert',
                    value: switch (s.useByDays) {
                      0 => 'On the day',
                      1 => '1 day before',
                      final d => '$d days before',
                    },
                    last: true,
                    onTap: () async {
                      final v = await _askNumber(
                        context,
                        'Days before the use-by date',
                        s.useByDays.toDouble(),
                        'days',
                      );
                      if (v != null && v <= 14) await s.setLowDefaults(useBy: v.round());
                    },
                  ),
                  Text('Each item can have its own warning point too.', style: T.small),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Opens the add sheet; asks for notification permission with the first item.
Future<void> addStock(BuildContext context) async {
  final first = Store.i.stock.isEmpty;
  final added = await showPaperSheet<bool>(context, (_) => const _AddSheet());
  if (added == true && first && Store.i.stockAlerts) await Reminders.askPermission();
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(S.radius)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nothing stocked yet', style: T.heading),
        const SizedBox(height: 8),
        Text(
          'Add what you buy, like “10 eggs, 450 g chicken breast”. Log “2 eggs” and it goes to 8. '
          'Cooked weights are worked back to raw, and nomnom asks when it isn’t sure.',
          style: T.body.copyWith(color: C.ink2),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add to pantry', onTap: onAdd),
      ],
    ),
  );
}

class _Checks extends StatelessWidget {
  const _Checks({required this.entries});

  final List<Entry> entries;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(S.radius),
      border: Border.all(color: C.lineStrong),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entries.length == 1 ? 'One meal to check' : '${entries.length} meals to check',
          style: T.heading.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 2),
        Text('nomnom wasn’t sure what these took from the pantry.', style: T.small),
        for (final (i, e) in entries.take(5).indexed)
          RuledRow(
            label: e.title,
            value: '${dayLabel(e.at)} · ${e.meal.label.toLowerCase()}',
            last: i == entries.take(5).length - 1,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => ReviewScreen.edit(entry: e))),
          ),
      ],
    ),
  );
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item, required this.onTap, this.last = false});

  final StockItem item;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final frac = item.full <= 0 ? 0.0 : (item.left / item.full).clamp(0.0, 1.0);
    final warn = item.isOut || item.isLow;
    final tags = [
      if (item.isOut) 'Out' else if (item.isLow) 'Low',
      if (item.useBy != null) 'Use by ${_useBy(item.useBy!)}',
    ];
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: C.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(item.name, style: T.body)),
                Text(
                  item.amount(),
                  style: T.bodyStrong.copyWith(color: item.isOut ? C.tomato : C.ink),
                ),
                Text(' / ${item.amount(item.full)}', style: T.small),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 4, color: C.line),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(height: 4, color: warn ? C.tomato : C.ink),
                  ),
                ],
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(tags.join(' · '), style: T.small.copyWith(color: warn ? C.tomato : C.ink2)),
            ],
          ],
        ),
      ),
    );
  }
}

String _useBy(DateTime d) {
  final days = daysBetween(DateTime.now(), d);
  if (days < 0) return DateFormat('d MMM').format(d);
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return DateFormat.EEEE().format(d);
  return DateFormat('d MMM').format(d);
}

// Adding

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _c = TextEditingController();
  List<StockDraft>? _drafts;
  bool _tried = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _read(String t) {
    setState(() {
      _drafts = t.trim().isEmpty ? null : readStock(t, FoodDb.i, country: Store.i.profile.country);
    });
  }

  Future<void> _save() async {
    final drafts = _drafts;
    if (drafts == null) {
      setState(() => _tried = true);
      return;
    }
    final now = DateTime.now();
    for (final d in drafts) {
      // Same food already stocked: this is a restock, not a second row.
      final same = Store.i.stock
          .where((s) => s.name.toLowerCase() == d.name.toLowerCase() && s.unit == d.unit)
          .firstOrNull;
      if (same != null) {
        final left = same.left + d.amount;
        await Store.i.putStock(same.copyWith(left: left, full: left));
      } else {
        await Store.i.putStock(d.toItem(Store.newId(), now));
      }
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add to pantry', style: T.heading),
          const SizedBox(height: 4),
          Text('Each with an amount. Weights as bought.', style: T.small),
          const SizedBox(height: 16),
          PaperField(
            label: 'What did you buy?',
            controller: _c,
            hint: '10 eggs, 450 g chicken breast',
            autofocus: true,
            onChanged: _read,
          ),
          const SizedBox(height: 12),
          if (drafts != null)
            for (final d in drafts) _DraftRow(draft: d, onChanged: () => setState(() {}))
          else if (_tried || _c.text.trim().length > 4)
            Text(
              'Give each one an amount: “6 eggs”, “1 kg rice”, “500 ml milk”.',
              style: T.small.copyWith(color: C.tomato),
            ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: drafts == null || drafts.length < 2 ? 'Add' : 'Add ${drafts.length}',
            onTap: drafts == null ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({required this.draft, required this.onChanged});

  final StockDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(child: Text(draft.name, style: T.body)),
        Text(formatStock(draft.amount, draft.unit), style: T.bodyStrong),
        if (draft.unit != 'piece') ...[
          const SizedBox(width: 10),
          Pressable(
            onTap: () {
              draft.raw = !draft.raw;
              onChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: C.lineStrong),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(draft.raw ? 'raw' : 'cooked', style: T.small),
            ),
          ),
        ],
      ],
    ),
  );
}

// Editing

class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.id});

  final String id;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  final _bought = TextEditingController();
  final _left = TextEditingController();

  StockItem? get _item => Store.i.stockItem(widget.id);

  @override
  void dispose() {
    _bought.dispose();
    _left.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  /// Typed amounts are in the shown unit; kg and l are typed as g and ml.
  Future<void> _apply() async {
    final s = _item!;
    final bought = _num(_bought);
    final left = _num(_left);
    if (bought != null && bought > 0) {
      final now = s.left + bought;
      await Store.i.putStock(s.copyWith(left: now, full: now));
    } else if (left != null && left >= 0) {
      await Store.i.putStock(s.copyWith(left: left, full: left > s.full ? left : null));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickUseBy() async {
    final s = _item!;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: s.useBy ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (d != null) await Store.i.putStock(s.copyWith(useBy: () => d));
    setState(() {});
  }

  Future<void> _delete() async {
    final s = _item!;
    await Store.i.deleteStock(s.id);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(
      context,
      'Removed ${s.name.toLowerCase()}',
      action: 'Undo',
      onAction: () => Store.i.putStock(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _item;
    if (s == null) return const SizedBox.shrink();
    final unit = s.counted ? null : s.unit;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.name, style: T.heading),
          const SizedBox(height: 4),
          Text(
            '${s.amount()} left of ${s.amount(s.full)}${s.counted || !s.raw ? '' : ' · weighed raw'}',
            style: T.small,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PaperField(
                  label: 'Bought more',
                  controller: _bought,
                  hint: '0',
                  suffix: unit,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => setState(() => _left.clear()),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: PaperField(
                  label: 'Or set what’s left',
                  controller: _left,
                  hint: formatNum((s.left * 10).round() / 10),
                  suffix: unit,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  onChanged: (_) => setState(() => _bought.clear()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RuledRow(
            label: 'Use by',
            value: s.useBy == null ? 'Not set' : _useBy(s.useBy!),
            onTap: _pickUseBy,
          ),
          if (s.useBy != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextLink(
                label: 'Clear date',
                color: C.ink2,
                onTap: () async {
                  await Store.i.putStock(s.copyWith(useBy: () => null));
                  setState(() {});
                },
              ),
            ),
          RuledRow(
            label: 'Warn when down to',
            value: '${s.amount(s.lowMark)}${s.lowAt == null ? ' · default' : ''}',
            onTap: () async {
              final v = await _askNumber(context, 'Warn when down to', s.lowMark, unit);
              if (v != null) await Store.i.putStock(s.copyWith(lowAt: () => v));
              setState(() {});
            },
          ),
          if (s.lowAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextLink(
                label: 'Use the default',
                color: C.ink2,
                onTap: () async {
                  await Store.i.putStock(s.copyWith(lowAt: () => null));
                  setState(() {});
                },
              ),
            ),
          if (!s.counted)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weighed raw', style: T.body),
                        Text('Cooked amounts you log are worked back to raw', style: T.small),
                      ],
                    ),
                  ),
                  PaperSwitch(
                    label: 'Weighed raw',
                    value: s.raw,
                    onChanged: (v) async {
                      await Store.i.putStock(s.copyWith(raw: v));
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          if (s.links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Also counts: ${s.links.join(', ')}', style: T.small),
            ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save', onTap: _apply),
          const SizedBox(height: 4),
          Center(
            child: TextLink(label: 'Remove from pantry', color: C.ink2, onTap: _delete),
          ),
        ],
      ),
    );
  }
}

Future<double?> _askNumber(BuildContext context, String title, double value, String? unit) {
  final c = TextEditingController(text: formatNum((value * 10).round() / 10));
  return showPaperSheet<double>(
    context,
    (context) => Padding(
      padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: T.heading),
          const SizedBox(height: 18),
          PaperField(
            label: 'Amount',
            controller: c,
            autofocus: true,
            suffix: unit,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Save',
            onTap: () {
              final n = double.tryParse(c.text.replaceAll(',', '.'));
              if (n != null && n >= 0) Navigator.pop(context, n);
            },
          ),
        ],
      ),
    ),
  );
}
