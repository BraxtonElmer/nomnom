import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../nutrition/countries.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/controls.dart';
import '../../ui/pressable.dart';

/// Country, units and body stats. Edits a [Profile] in place via [onChanged].
class AboutForm extends StatefulWidget {
  const AboutForm({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  State<AboutForm> createState() => _AboutFormState();
}

class _AboutFormState extends State<AboutForm> {
  late final _age = TextEditingController(text: '${widget.profile.age}');
  late final _cm = TextEditingController();
  late final _ft = TextEditingController();
  late final _in = TextEditingController();
  late final _weight = TextEditingController();

  Profile get p => widget.profile;

  @override
  void initState() {
    super.initState();
    _fillBody(p);
  }

  void _fillBody(Profile p) {
    _cm.text = p.heightCm.round().toString();
    final inches = (p.heightCm / 2.54).round();
    _ft.text = '${inches ~/ 12}';
    _in.text = '${inches % 12}';
    _weight.text = p.metric
        ? formatNum((p.weightKg * 10).round() / 10)
        : formatNum((p.weightKg * 2.20462).roundToDouble());
  }

  @override
  void dispose() {
    for (final c in [_age, _cm, _ft, _in, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  void _bodyChanged() {
    final height = p.metric ? _num(_cm) : (_num(_ft) * 12 + _num(_in)) * 2.54;
    final weight = p.metric ? _num(_weight) : _num(_weight) / 2.20462;
    widget.onChanged(p.copyWith(
      age: _num(_age).round().clamp(0, 120),
      heightCm: height,
      weightKg: weight,
    ));
  }

  Future<void> _pickCountry() async {
    final code = await showPaperSheet<String>(context, (_) => const _CountrySheet());
    if (code == null) return;
    final metric = !imperialByDefault.contains(code);
    final next = p.copyWith(country: code, metric: metric);
    if (metric != p.metric) _fillBody(next);
    widget.onChanged(next);
  }

  static final _digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('COUNTRY', style: T.caps),
      Pressable(
        onTap: _pickCountry,
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.ink, width: 1.2))),
          child: Row(children: [
            Expanded(child: Text(countryName(p.country), style: T.body.copyWith(fontSize: 18))),
            const Icon(Icons.expand_more_rounded, color: C.ink2),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Text('Used to estimate local dishes and portion sizes.', style: T.small),
      const SizedBox(height: 26),
      Row(children: [
        Expanded(
          child: Segmented<bool>(
            values: const [true, false],
            labels: const ['Metric', 'Imperial'],
            value: p.metric,
            onChanged: (m) {
              final next = p.copyWith(metric: m);
              _fillBody(next);
              widget.onChanged(next);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Segmented<Sex>(
            values: const [Sex.male, Sex.female],
            labels: const ['Male', 'Female'],
            value: p.sex,
            onChanged: (s) => widget.onChanged(p.copyWith(sex: s)),
          ),
        ),
      ]),
      const SizedBox(height: 26),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: PaperField(
              label: 'Age', controller: _age, keyboard: TextInputType.number,
              formatters: _digits, suffix: 'yrs', onChanged: (_) => _bodyChanged()),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: PaperField(
              label: 'Weight', controller: _weight,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              formatters: _digits, suffix: p.metric ? 'kg' : 'lb',
              onChanged: (_) => _bodyChanged()),
        ),
      ]),
      const SizedBox(height: 22),
      if (p.metric)
        PaperField(
            label: 'Height', controller: _cm, keyboard: TextInputType.number,
            formatters: _digits, suffix: 'cm', onChanged: (_) => _bodyChanged())
      else
        Row(children: [
          Expanded(
            child: PaperField(
                label: 'Height', controller: _ft, keyboard: TextInputType.number,
                formatters: _digits, suffix: 'ft', onChanged: (_) => _bodyChanged()),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: PaperField(
                label: '', controller: _in, keyboard: TextInputType.number,
                formatters: _digits, suffix: 'in', onChanged: (_) => _bodyChanged()),
          ),
        ]),
      const SizedBox(height: 30),
      const Text('HOW ACTIVE ARE YOU?', style: T.caps),
      const SizedBox(height: 4),
      for (final (i, a) in activityLevels.indexed)
        RadioRow(
          title: a.$2,
          subtitle: a.$3,
          selected: (p.activity - a.$1).abs() < 0.01,
          last: i == activityLevels.length - 1,
          onTap: () => widget.onChanged(p.copyWith(activity: a.$1)),
        ),
    ]);
  }
}

/// Ruled radio choice with an ink dot.
class RadioRow extends StatelessWidget {
  const RadioRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.selected,
    required this.onTap,
    this.last = false,
  });

  final String title;
  final String? subtitle;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: C.line)),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: Motion.fast,
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? C.ink : C.ink3, width: selected ? 5 : 1.5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.body.copyWith(fontSize: 17)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: T.small),
              ],
            ]),
          ),
          if (trailing != null) Text(trailing!, style: T.small),
        ]),
      ),
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = countries.entries
        .where((e) => e.value.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            style: T.body.copyWith(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Search countries',
              hintStyle: T.body.copyWith(fontSize: 18, color: C.ink3),
              prefixIcon: const Icon(Icons.search_rounded, color: C.ink2),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.ink)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: C.tomato)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: list.length,
            itemBuilder: (context, i) => RuledRow(
              label: list[i].value,
              value: list[i].key == 'IN' ? 'Dish table' : null,
              onTap: () => Navigator.pop(context, list[i].key),
            ),
          ),
        ),
      ]),
    );
  }
}
