import 'package:flutter/material.dart';

import '../../data/activity.dart';
import '../../data/models.dart';
import '../../data/reminders.dart';
import '../../data/store.dart';
import '../../nutrition/countries.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/macro_bar.dart';
import '../../ui/pressable.dart';
import '../setup/about_form.dart';
import '../setup/ai_form.dart';
import '../setup/goal_form.dart';
import 'backup.dart';

class YouScreen extends StatelessWidget {
  const YouScreen({super.key});

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        final p = s.profile;
        final t = s.targets;
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(S.gutter, 12, S.gutter, 40),
            children: [
              const Text('You', style: T.title),
              const SizedBox(height: 20),
              Pressable(
                onTap: () => _push(context, const _GoalEdit()),
                scale: 0.985,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(S.radius),
                    boxShadow: const [
                      BoxShadow(color: C.lineStrong, offset: Offset(0, 1)),
                      BoxShadow(color: Color(0x121A1916), blurRadius: 24, offset: Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(p.goal.label.toUpperCase(), style: T.caps),
                          const Spacer(),
                          Text(
                            'Edit',
                            style: T.small.copyWith(color: C.tomato, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(kcal(t.kcal), style: T.display.copyWith(fontSize: 40)),
                          const SizedBox(width: 8),
                          Text(
                            p.customKcal != null ? 'kcal a day · your own' : 'kcal a day',
                            style: T.small,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _m('Protein', t.protein, C.protein),
                          _m('Carbs', t.carbs, C.carbs),
                          _m('Fat', t.fat, C.fat),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text('PROFILE', style: T.caps),
              RuledRow(
                label: 'Country',
                value: countryName(p.country),
                onTap: () => _push(context, const _ProfileEdit()),
              ),
              RuledRow(
                label: 'Body',
                value: '${p.age} yrs · ${cm(p.heightCm, p.metric)} · ${kg(p.weightKg, p.metric)}',
                onTap: () => _push(context, const _ProfileEdit()),
              ),
              RuledRow(
                label: 'BMI',
                value: bmiLabel(p).replaceFirst('BMI ', ''),
                onTap: () => _push(context, const _ProfileEdit()),
              ),
              RuledRow(
                label: 'Activity',
                value: activityLabel(p.activity),
                onTap: () => _push(context, const _ProfileEdit()),
                last: true,
              ),
              const SizedBox(height: 28),
              const Text('AI MODEL', style: T.caps),
              RuledRow(
                label: s.ai.provider.label,
                value: s.ai.ready ? s.ai.model : 'Not connected',
                onTap: () => _push(context, const _AiEdit()),
              ),
              RuledRow(
                label: 'Nutrition numbers',
                value: s.aiOnly ? 'AI estimates' : 'Food tables first',
                last: true,
                onTap: () => _pickNumbers(context),
              ),
              if (Activity.supported) ...[
                const SizedBox(height: 28),
                const Text('HEALTH CONNECT', style: T.caps),
                if (!s.healthConnected)
                  RuledRow(
                    label: 'Connect steps & activity',
                    value: 'Off',
                    last: true,
                    onTap: () => _connectHealth(context),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Add exercise to my budget', style: T.body),
                              const SizedBox(height: 2),
                              Text('Active calories burned raise the day’s goal', style: T.small),
                            ],
                          ),
                        ),
                        PaperSwitch(
                          value: s.eatBack,
                          label: 'Add exercise to my budget',
                          onChanged: (v) => Store.i.setHealth(eatBack: v),
                        ),
                      ],
                    ),
                  ),
                  RuledRow(
                    label: 'Disconnect Health Connect',
                    last: true,
                    onTap: () => Activity.i.disconnect(),
                  ),
                ],
              ],
              if (Reminders.supported) ...[
                const SizedBox(height: 28),
                const Text('REMINDERS', style: T.caps),
                _ToggleRow(
                  title: 'Remind me to log',
                  subtitle: 'Only for meals you haven’t logged yet',
                  value: s.remindersOn,
                  last: !s.remindersOn,
                  onChanged: (v) async {
                    if (!v) return Store.i.setReminders(on: false);
                    final ok = await Reminders.enable();
                    if (!ok && context.mounted) {
                      showToast(context, 'Notifications are off for nomnom in system settings.');
                    }
                  },
                ),
                if (s.remindersOn)
                  for (final (i, meal) in Reminders.meals.indexed)
                    RuledRow(
                      label: meal.label,
                      value: _clock(context, s.reminderAt(meal)),
                      last: i == Reminders.meals.length - 1,
                      onTap: () async {
                        final m = s.reminderAt(meal);
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
                        );
                        if (t != null) {
                          await Store.i.setReminders(meal: meal, minutes: t.hour * 60 + t.minute);
                        }
                      },
                    ),
              ],
              const SizedBox(height: 28),
              const Text('FAVOURITES', style: T.caps),
              RuledRow(
                label: 'Saved plates',
                value: s.favourites.isEmpty ? 'None yet' : '${s.favourites.length}',
                onTap: () => _push(context, const _Favourites()),
                last: true,
              ),
              const SizedBox(height: 28),
              const Text('YOUR DATA', style: T.caps),
              RuledRow(label: 'Export a backup', onTap: () => exportBackup(context)),
              RuledRow(label: 'Restore from a backup', onTap: () => restoreBackup(context)),
              RuledRow(
                label: 'Delete everything',
                danger: true,
                last: true,
                onTap: () async {
                  final ok = await confirm(
                    context,
                    title: 'Delete everything?',
                    body:
                        'Your log, weights, favourites, goals and saved API keys will be '
                        'erased from this phone. Export a backup first if you might want them.',
                    action: 'Delete',
                  );
                  if (ok) await Store.i.wipe();
                },
              ),
              const SizedBox(height: 36),
              const Text('nomnom', style: T.brand),
              const SizedBox(height: 6),
              Text(
                'Version 2.2.0. Everything stays on this phone; the AI is called directly '
                'with your own key. Nutrition data from USDA FoodData Central, Open Food '
                'Facts and the nomnom dish table. Estimates, not medical advice.',
                style: T.small,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickNumbers(BuildContext context) => showPaperSheet<void>(
    context,
    (context) => ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nutrition numbers', style: T.heading),
            const SizedBox(height: 8),
            RadioRow(
              title: 'Food tables first',
              subtitle:
                  'USDA, dish tables and Open Food Facts; the AI fills gaps. '
                  'Same food, same numbers, every time.',
              selected: !Store.i.aiOnly,
              onTap: () => Store.i.setAiOnly(false),
            ),
            RadioRow(
              title: 'AI estimates',
              subtitle:
                  'The model estimates everything. One request per log instead of '
                  'two, but numbers can drift between logs.',
              selected: Store.i.aiOnly,
              last: true,
              onTap: () => Store.i.setAiOnly(true),
            ),
            const SizedBox(height: 10),
            Text(
              'Either way you can switch any single item between the two from the review '
              'screen.',
              style: T.small,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _connectHealth(BuildContext context) async {
    if (!await Activity.i.available()) {
      if (!context.mounted) return;
      showToast(
        context,
        'Health Connect isn’t installed or needs an update.',
        action: 'Get it',
        onAction: Activity.i.openInstall,
      );
      return;
    }
    final ok = await Activity.i.connect();
    if (context.mounted && !ok) {
      showToast(context, 'Permission wasn’t granted. You can allow it in Health Connect.');
    }
  }

  Widget _m(String label, double g, Color c) => Text.rich(
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

/// Page with a title, scrolling body and a pinned Save button.
class _EditPage extends StatelessWidget {
  const _EditPage({required this.title, required this.child, this.onSave});

  final String title;
  final Widget child;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.gutter, 8, S.gutter, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(title, style: T.display),
                const SizedBox(height: 26),
                child,
              ],
            ),
          ),
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(S.gutter, 0, S.gutter, 16),
              child: PrimaryButton(label: 'Save', onTap: onSave),
            ),
        ],
      ),
    ),
  );
}

class _ProfileEdit extends StatefulWidget {
  const _ProfileEdit();

  @override
  State<_ProfileEdit> createState() => _ProfileEditState();
}

class _ProfileEditState extends State<_ProfileEdit> {
  Profile _p = Store.i.profile;

  @override
  Widget build(BuildContext context) => _EditPage(
    title: 'About you',
    onSave: () async {
      final weightChanged = (_p.weightKg - Store.i.profile.weightKg).abs() > 0.05;
      await Store.i.saveProfile(_p);
      if (weightChanged) await Store.i.logWeight(DateTime.now(), _p.weightKg);
      if (context.mounted) Navigator.pop(context);
    },
    child: AboutForm(profile: _p, onChanged: (p) => setState(() => _p = p)),
  );
}

class _GoalEdit extends StatefulWidget {
  const _GoalEdit();

  @override
  State<_GoalEdit> createState() => _GoalEditState();
}

class _GoalEditState extends State<_GoalEdit> {
  Profile _p = Store.i.profile;

  @override
  Widget build(BuildContext context) => _EditPage(
    title: 'Your goal',
    onSave: () async {
      await Store.i.saveProfile(_p);
      if (context.mounted) Navigator.pop(context);
    },
    child: GoalForm(profile: _p, onChanged: (p) => setState(() => _p = p)),
  );
}

class _AiEdit extends StatelessWidget {
  const _AiEdit();

  @override
  Widget build(BuildContext context) => _EditPage(
    title: 'AI model',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'nomnom reads your meals with this model. Calls go straight from your phone '
          'to the provider; the key is kept in the phone’s secure storage.',
          style: T.body.copyWith(color: C.ink2),
        ),
        const SizedBox(height: 18),
        const AiForm(),
      ],
    ),
  );
}

class _Favourites extends StatelessWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Store.i,
    builder: (context, _) {
      final favs = Store.i.favourites;
      return _EditPage(
        title: 'Favourites',
        child: favs.isEmpty
            ? Text(
                'Open any logged meal and tap the star to save it here. Favourites show '
                'up above the log bar for one-tap logging.',
                style: T.body.copyWith(color: C.ink2),
              )
            : Column(
                children: [
                  for (final (i, f) in favs.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: i == favs.length - 1
                            ? null
                            : const Border(bottom: BorderSide(color: C.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(f.title, style: T.body),
                                const SizedBox(height: 2),
                                Text(
                                  '${kcal(f.total.kcal)} kcal · ${macros(f.total)}',
                                  style: T.small,
                                ),
                              ],
                            ),
                          ),
                          CircleIconButton(
                            icon: Icons.close_rounded,
                            label: 'Remove ${f.title}',
                            onTap: () => Store.i.removeFavourite(f.title),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      );
    },
  );
}

String _clock(BuildContext context, int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: T.body),
              const SizedBox(height: 2),
              Text(subtitle, style: T.small),
            ],
          ),
        ),
        PaperSwitch(value: value, label: title, onChanged: onChanged),
      ],
    ),
  );
}
