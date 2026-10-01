import 'package:flutter/material.dart';

import '../../ai/client.dart';
import '../../ai/meal_parser.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/countries.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/pressable.dart';
import '../shell.dart';
import 'item_sheet.dart';

/// Shows what a sentence turned into and lets you fix it before saving.
/// Also the editor for entries already in the log.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen.parse({super.key, required String this.text, required DateTime this.at})
      : entry = null;

  const ReviewScreen.edit({super.key, required Entry this.entry})
      : text = null,
        at = null;

  final String? text;
  final DateTime? at;
  final Entry? entry;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<ParsedItem>? _items;
  String _title = '';
  late Meal _meal;
  late DateTime _at;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.entry != null;
  String get _text => widget.entry?.text ?? widget.text!;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    if (e != null) {
      _at = e.at;
      _meal = e.meal;
      _title = e.title;
      _items = [
        for (final i in e.items) ParsedItem(item: i, estimate: i, candidates: const [])
      ];
    } else {
      _at = widget.at!;
      _meal = Meal.forTime(DateTime.now());
      _run();
    }
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final parser = await MealParser.fromSettings();
      final meal = await parser.parse(_text);
      if (!mounted) return;
      setState(() {
        _items = meal.items;
        _title = meal.title;
        if (meal.meal != null) _meal = meal.meal!;
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong reading that. Try again.');
    }
  }

  Nutrients get _total =>
      (_items ?? const []).fold(Nutrients.zero, (s, p) => s + p.item.total);

  Future<void> _save() async {
    final items = _items!;
    if (items.isEmpty) return;
    setState(() => _saving = true);
    final entry = Entry(
      id: widget.entry?.id ?? Store.newId(),
      at: _at,
      meal: _meal,
      title: _title.isEmpty ? items.map((p) => p.item.name).take(3).join(', ') : _title,
      text: _text,
      items: [for (final p in items) p.item.copyWith(flagged: false)],
    );
    await Store.i.putEntry(entry);
    if (!mounted) return;
    Navigator.pop(context);
    if (!_editing) {
      showToast(context, 'Added to ${_meal.label.toLowerCase()} · ${kcal(entry.total.kcal)} kcal');
    }
  }

  Future<void> _delete() async {
    final e = widget.entry!;
    await Store.i.deleteEntry(e.id);
    if (!mounted) return;
    Navigator.pop(context);
    showToast(context, 'Deleted ${e.title}', action: 'Undo', onAction: () => Store.i.putEntry(e));
  }

  Future<void> _editItem(int i) async {
    final res = await showItemSheet(context, _items![i]);
    if (res == null || !mounted) return;
    setState(() {
      if (res.delete) {
        _items!.removeAt(i);
      } else {
        _items![i].item = res.item!;
      }
    });
  }

  Future<void> _addItem() async {
    final res = await showItemSheet(context, null);
    if (res?.item != null && mounted) {
      setState(() => _items!.add(
          ParsedItem(item: res!.item!, estimate: res.item!, candidates: const [])));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: C.ink, onPrimary: C.paper, surface: C.card),
        ),
        child: child!,
      ),
    );
    if (t != null) {
      setState(() => _at = DateTime(_at.year, _at.month, _at.day, t.hour, t.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final fav = _editing && Store.i.isFavourite(_title);
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Text((_editing ? 'Edit entry' : 'Review entry').toUpperCase(), style: T.caps),
              const Spacer(),
              if (_editing) ...[
                CircleIconButton(
                  icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
                  label: fav ? 'Remove from favourites' : 'Add to favourites',
                  onTap: () async {
                    if (fav) {
                      await Store.i.removeFavourite(_title);
                    } else {
                      await Store.i.addFavourite(widget.entry!.copyWith(
                          items: [for (final p in _items!) p.item], title: _title));
                    }
                    setState(() {});
                  },
                ),
                CircleIconButton(
                    icon: Icons.delete_outline_rounded, label: 'Delete entry', onTap: _delete),
              ],
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.gutter, 14, S.gutter, 16),
              children: [
                if (_text.isNotEmpty)
                  Text('“$_text”',
                      style: T.title.copyWith(fontStyle: FontStyle.italic, fontSize: 32))
                else
                  Text(_title, style: T.title.copyWith(fontSize: 32)),
                const SizedBox(height: 10),
                Text(
                  items == null && _error == null
                      ? 'Reading your plate…'
                      : 'Estimated for ${countryName(Store.i.profile.country)} · tap an item to adjust',
                  style: T.small,
                ),
                const SizedBox(height: 18),
                const Hairline(strong: true),
                AnimatedSwitcher(
                  duration: Motion.base,
                  child: _error != null
                      ? _ErrorBlock(message: _error!, onRetry: _run)
                      : items == null
                          ? const _Skeleton()
                          : Column(
                              key: const ValueKey('items'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  _ItemRow(
                                    item: items[i].item,
                                    onTap: () => _editItem(i),
                                    onStep: (d) =>
                                        setState(() => items[i].item = items[i].item.step(d)),
                                  ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextLink(label: '+ Add an item', onTap: _addItem),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
          if (items != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: S.gutter),
              child: Row(children: [
                Expanded(
                  child: TextTabs<Meal>(
                    values: Meal.values,
                    labels: Meal.values.map((m) => m.label).toList(),
                    value: _meal,
                    onChanged: (m) => setState(() => _meal = m),
                  ),
                ),
                Pressable(
                  onTap: _pickTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(time(_at), style: T.small.copyWith(color: C.ink)),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: PrimaryButton(
                label: _editing ? 'Save changes' : 'Add to ${_meal.label.toLowerCase()}',
                trailing: '${kcal(_total.kcal)} kcal',
                busy: _saving,
                onTap: items.isEmpty ? null : _save,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap, required this.onStep});

  final FoodItem item;
  final VoidCallback onTap;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final t = item.total;
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Expanded(child: Text(item.name, style: T.body.copyWith(fontSize: 17))),
            Text(kcal(t.kcal), style: T.heading.copyWith(fontSize: 26)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            QtyStepper(
              label: item.qtyLabel,
              onMinus: () => onStep(-1),
              onPlus: () => onStep(1),
            ),
            const SizedBox(width: 10),
            if (!item.byWeight) Text('≈ ${item.grams.round()} g', style: T.small),
            const Spacer(),
            Text(macros(t), style: T.small),
          ]),
          const SizedBox(height: 8),
          SourceTag(item: item),
        ]),
      ),
    );
  }
}

/// Where the numbers came from, and a nudge when they look off.
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.flagged ? C.tomato : (item.source == Source.ai ? C.carbs : C.ink3);
    final label = item.flagged
        ? 'Check this one · ${item.source.label}'
        : item.source == Source.ai
            ? 'AI estimate · no table match'
            : item.source.label;
    return Row(children: [
      Icon(
        item.flagged
            ? Icons.error_outline_rounded
            : item.source == Source.ai
                ? Icons.auto_awesome_outlined
                : Icons.menu_book_outlined,
        size: 14,
        color: color,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label,
            style: T.small.copyWith(color: color, fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _Skeleton extends StatefulWidget {
  const _Skeleton();

  @override
  State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: C.paperDeep, borderRadius: BorderRadius.circular(6)),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [bar(140.0 + i * 30, 16), const Spacer(), bar(44, 22)]),
              const SizedBox(height: 14),
              Row(children: [bar(120, 34), const Spacer(), bar(80, 12)]),
            ]),
          ),
      ]),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final needsKey = message.contains('Connect an AI') || message.contains('rejected');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: T.body),
        const SizedBox(height: 18),
        Row(children: [
          OutlineButton(label: 'Try again', icon: Icons.refresh_rounded, onTap: onRetry),
          if (needsKey) ...[
            const SizedBox(width: 10),
            OutlineButton(
              label: 'Open settings',
              onTap: () {
                Navigator.popUntil(context, (r) => r.isFirst);
                Shell.tab.value = 3;
              },
            ),
          ],
        ]),
      ]),
    );
  }
}
