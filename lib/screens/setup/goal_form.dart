import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/models.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/controls.dart';
import '../../ui/macro_bar.dart';
import '../../ui/pressable.dart';
import 'about_form.dart';

final _fmt = NumberFormat.decimalPattern();

/// Goal, pace, macro split and the daily target, with an override.
class GoalForm extends StatefulWidget {
  const GoalForm({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  State<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<GoalForm> {
  late final _kcal = TextEditingController(
    text: '${widget.profile.customKcal ?? Targets.of(widget.profile).suggested.round()}',
  );

  Profile get p => widget.profile;

  @override
  void dispose() {
    _kcal.dispose();
    super.dispose();
  }

  void _setCustom(int? v) {
    widget.onChanged(p.copyWith(customKcal: () => v));
  }

  void _nudge(int d) {
    final now = p.customKcal ?? Targets.of(p).suggested.round();
    final next = ((now + d) / 10).round() * 10;
    _kcal.text = '${next.clamp(800, 6000)}';
    _setCustom(next.clamp(800, 6000));
  }

  @override
  Widget build(BuildContext context) {
    final t = Targets.of(p);
    final custom = p.customKcal != null;
    final paces = p.metric ? const [0.25, 0.5, 0.75, 1.0] : const [0.227, 0.454, 0.68, 0.907];
    final paceLabels = p.metric
        ? const ['0.25 kg', '0.5 kg', '0.75 kg', '1 kg']
        : const ['0.5 lb', '1 lb', '1.5 lb', '2 lb'];
    final paceIndex = paces.indexWhere((v) => (v - p.paceKg).abs() < 0.03);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('YOUR GOAL', style: T.caps),
        const SizedBox(height: 4),
        for (final (i, g) in Goal.values.indexed)
          RadioRow(
            title: g.label,
            selected: p.goal == g,
            last: i == Goal.values.length - 1,
            onTap: () => widget.onChanged(p.copyWith(goal: g)),
          ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          child: p.goal == Goal.maintain
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('PACE PER WEEK', style: T.caps),
                      const SizedBox(height: 10),
                      Segmented<int>(
                        values: const [0, 1, 2, 3],
                        labels: paceLabels,
                        value: paceIndex < 0 ? 1 : paceIndex,
                        onChanged: (i) => widget.onChanged(p.copyWith(paceKg: paces[i])),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 26),
        const Text('MACRO SPLIT', style: T.caps),
        const SizedBox(height: 10),
        Segmented<MacroPreset>(
          values: MacroPreset.values,
          labels: MacroPreset.values.map((m) => m.label).toList(),
          value: p.macros,
          onChanged: (m) => widget.onChanged(p.copyWith(macros: m)),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: C.card,
            borderRadius: BorderRadius.circular(S.radius),
            boxShadow: const [
              BoxShadow(color: C.lineStrong, offset: Offset(0, 1)),
              BoxShadow(color: Color(0x141A1916), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('DAILY TARGET', style: T.caps)),
                  Pressable(
                    onTap: () {
                      if (custom) {
                        _setCustom(null);
                        _kcal.text = '${t.suggested.round()}';
                      } else {
                        _setCustom(t.suggested.round());
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        custom ? 'Use suggested' : 'Set my own',
                        style: T.small.copyWith(color: C.tomato, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: Motion.base,
                child: custom
                    ? Row(
                        key: const ValueKey('custom'),
                        children: [
                          _RoundBtn(label: '−', onTap: () => _nudge(-50)),
                          Expanded(
                            child: TextField(
                              controller: _kcal,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: T.display,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                helperText: 'kcal a day',
                                helperStyle: T.small,
                              ),
                              onChanged: (v) {
                                final n = int.tryParse(v);
                                if (n != null && n >= 800 && n <= 6000) _setCustom(n);
                              },
                            ),
                          ),
                          _RoundBtn(label: '+', onTap: () => _nudge(50)),
                        ],
                      )
                    : Row(
                        key: const ValueKey('auto'),
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_fmt.format(t.kcal.round()), style: T.display),
                          const SizedBox(width: 8),
                          Text('kcal a day', style: T.small),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                custom
                    ? 'Suggested for you: ${_fmt.format(t.suggested.round())} kcal'
                    : 'Maintenance is about ${_fmt.format(t.maintenance.round())} kcal. '
                          '${p.goal == Goal.maintain ? '' : 'This sets a steady ${p.goal == Goal.lose ? 'deficit' : 'surplus'}.'}',
                style: T.small,
              ),
              const SizedBox(height: 14),
              const Hairline(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _macro('Protein', t.protein, C.protein),
                  _macro('Carbs', t.carbs, C.carbs),
                  _macro('Fat', t.fat, C.fat),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _macro(String label, double g, Color c) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: Dot(c)),
        TextSpan(text: '$label '),
        TextSpan(
          text: '${g.round()}g',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    ),
    style: T.small.copyWith(color: C.ink),
  );
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.85,
    semanticLabel: label == '+' ? 'Increase' : 'Decrease',
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: C.ink),
      ),
      alignment: Alignment.center,
      child: Text(label, style: T.body.copyWith(fontSize: 20)),
    ),
  );
}
