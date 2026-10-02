import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';

/// Log or correct a weigh-in for any day up to today. Returns the weigh-in
/// if it was deleted, so the caller can offer to undo it.
Future<WeightEntry?> showWeightSheet(BuildContext context, {DateTime? day}) =>
    showPaperSheet<WeightEntry>(context, (_) => _WeightSheet(day: day ?? DateTime.now()));

/// From a page (not another sheet): an undo toast after a delete.
Future<void> logWeight(BuildContext context) async {
  final removed = await showWeightSheet(context);
  if (removed != null && context.mounted) {
    showToast(
      context,
      'Removed the weigh-in for ${dayLabel(removed.day).toLowerCase()}',
      action: 'Undo',
      onAction: () => Store.i.logWeight(removed.day, removed.kg),
    );
  }
}

/// Every weigh-in, newest first, each one tappable to fix or delete.
Future<void> showWeighIns(BuildContext context) =>
    showPaperSheet<void>(context, (_) => const _WeighIns());

class _WeightSheet extends StatefulWidget {
  const _WeightSheet({required this.day});

  final DateTime day;

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  late DateTime _day = dayOf(widget.day);
  final _c = TextEditingController();

  bool get _metric => Store.i.profile.metric;

  WeightEntry? get _existing => Store.i.weights.where((w) => w.day == _day).firstOrNull;

  @override
  void initState() {
    super.initState();
    _fill();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// That day's weigh-in, else the nearest one before it, else the profile.
  void _fill() {
    final ws = Store.i.weights;
    final kg =
        _existing?.kg ??
        ws.where((w) => w.day.isBefore(_day)).lastOrNull?.kg ??
        Store.i.profile.weightKg;
    _c.text = weightText(kg, _metric);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (d == null) return;
    setState(() {
      _day = dayOf(d);
      _fill();
    });
  }

  Future<void> _save() async {
    final n = double.tryParse(_c.text.replaceAll(',', '.'));
    if (n == null || n <= 20 || n >= 700) return;
    await Store.i.logWeight(_day, _metric ? n : n / 2.20462);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final w = _existing!;
    await Store.i.deleteWeight(_day);
    if (mounted) Navigator.pop(context, w);
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(existing == null ? 'Log weight' : 'Edit weigh-in', style: T.heading),
          const SizedBox(height: 10),
          RuledRow(label: 'Day', value: _date(_day), onTap: _pickDay),
          const SizedBox(height: 14),
          PaperField(
            label: 'Weight',
            controller: _c,
            autofocus: true,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            suffix: _metric ? 'kg' : 'lb',
          ),
          const SizedBox(height: 24),
          PrimaryButton(label: existing == null ? 'Save' : 'Update', onTap: _save),
          if (existing != null) ...[
            const SizedBox(height: 4),
            Center(
              child: TextLink(label: 'Delete this weigh-in', color: C.ink2, onTap: _delete),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeighIns extends StatefulWidget {
  const _WeighIns();

  @override
  State<_WeighIns> createState() => _WeighInsState();
}

class _WeighInsState extends State<_WeighIns> {
  /// Just deleted, offered back here: a toast would sit behind this sheet.
  WeightEntry? _removed;

  Future<void> _open(DateTime? day) async {
    final r = await showWeightSheet(context, day: day);
    if (mounted) setState(() => _removed = r);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final ws = Store.i.weights.reversed.toList();
        final metric = Store.i.profile.metric;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text('Weigh-ins', style: T.heading)),
                  TextLink(label: '+ Add', onTap: () => _open(null)),
                ],
              ),
              if (_removed case final r?)
                Row(
                  children: [
                    Expanded(
                      child: Text('Removed ${_date(r.day)} · ${kg(r.kg, metric)}', style: T.small),
                    ),
                    TextLink(
                      label: 'Undo',
                      onTap: () async {
                        await Store.i.logWeight(r.day, r.kg);
                        setState(() => _removed = null);
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 6),
              if (ws.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No weigh-ins yet.', style: T.small),
                ),
              for (final (i, w) in ws.indexed)
                RuledRow(
                  label: _date(w.day),
                  value: kg(w.kg, metric),
                  last: i == ws.length - 1,
                  onTap: () => _open(w.day),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// "Today", "Yesterday", else the full date: a weekday alone is vague in a
/// list that goes back months.
String _date(DateTime d) {
  final days = daysBetween(d, DateTime.now());
  if (days <= 1) return dayLabel(d);
  return DateFormat(d.year == DateTime.now().year ? 'EEE, d MMM' : 'd MMM y').format(d);
}
