import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../you/backup.dart';
import 'about_form.dart';
import 'ai_form.dart';
import 'goal_form.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key});

  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pages = PageController();
  int _step = 0;
  Profile _profile = Store.i.profile;
  bool _connected = Store.i.ai.ready;

  static const _titles = [
    ('Step 1 of 3', 'A little about you.'),
    ('Step 2 of 3', 'What are you aiming for?'),
    ('Step 3 of 3', 'Bring your own key.'),
  ];

  bool get _valid => switch (_step) {
        1 => _profile.age >= 13 &&
            _profile.heightCm >= 100 &&
            _profile.heightCm <= 250 &&
            _profile.weightKg >= 30 &&
            _profile.weightKg <= 300,
        _ => true,
      };

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(step, duration: Motion.base, curve: Motion.curve);
  }

  Future<void> _finish() async {
    await Store.i.saveProfile(_profile);
    await Store.i.finishOnboarding();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        body: SafeArea(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Welcome(onStart: () => _go(1)),
              _step1(),
              _step2(),
              _step3(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame({required int step, required Widget child, required Widget footer}) {
    final (eyebrow, title) = _titles[step - 1];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, S.gutter, 0),
        child: Row(children: [
          CircleIconButton(
              icon: Icons.arrow_back_rounded, label: 'Back', onTap: () => _go(step - 1)),
          const SizedBox(width: 8),
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: AnimatedContainer(
                duration: Motion.base,
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i <= step ? C.ink : C.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(S.gutter, 20, S.gutter, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(eyebrow.toUpperCase(), style: T.caps),
            const SizedBox(height: 10),
            Text(title, style: T.display),
            const SizedBox(height: 28),
            child,
          ],
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(S.gutter, 0, S.gutter, 16), child: footer),
    ]);
  }

  Widget _step1() => _frame(
        step: 1,
        child: AboutForm(profile: _profile, onChanged: (p) => setState(() => _profile = p)),
        footer: PrimaryButton(label: 'Continue', onTap: _valid ? () => _go(2) : null),
      );

  Widget _step2() => _frame(
        step: 2,
        child: GoalForm(profile: _profile, onChanged: (p) => setState(() => _profile = p)),
        footer: PrimaryButton(label: 'Continue', onTap: () => _go(3)),
      );

  Widget _step3() => _frame(
        step: 3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            'nomnom talks to the AI straight from your phone. No servers, no accounts. '
            'Your key never leaves this device.',
            style: T.body.copyWith(color: C.ink2),
          ),
          const SizedBox(height: 18),
          AiForm(onConnected: () => setState(() => _connected = true)),
        ]),
        footer: Column(mainAxisSize: MainAxisSize.min, children: [
          PrimaryButton(label: 'Start logging', onTap: _connected ? _finish : null),
          if (!_connected)
            TextLink(label: 'Skip for now', color: C.ink2, onTap: _finish),
        ]),
      );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(S.gutter, 24, S.gutter, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('nomnom', style: T.brand.copyWith(fontSize: 34)),
        const Spacer(),
        Text('Type what you ate.', style: T.display.copyWith(fontSize: 52)),
        Text('Get the macros.',
            style: T.display.copyWith(fontSize: 52, fontStyle: FontStyle.italic, color: C.tomato)),
        const SizedBox(height: 28),
        const _Line('“2 rotis, dal and a bowl of curd”', 'becomes items, grams and macros'),
        const _Line('Numbers from real food tables', 'USDA plus regional dishes, not guesses'),
        const _Line('Runs on your phone', 'your own free AI key, no account'),
        const Spacer(),
        PrimaryButton(label: 'Get started', onTap: onStart),
        Center(
          child: TextLink(
            label: 'Restore from a backup',
            color: C.ink2,
            onTap: () => restoreBackup(context),
          ),
        ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.title, this.sub);

  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: C.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.body),
          const SizedBox(height: 2),
          Text(sub, style: T.small),
        ]),
      );
}
