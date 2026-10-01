import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/check_in.dart';
import '../../nutrition/targets.dart';
import '../../theme/tokens.dart';
import '../../ui/buttons.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/pressable.dart';

/// A proposed goal change from the user's own data. Shown first, applied
/// only when they say so.
class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, required this.checkIn});

  final CheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    final c = checkIn;
    final s = Store.i;
    final metric = s.profile.metric;
    final higher = c.measured > c.current;
    final trend = c.trendKgPerWeek.abs() < 0.05
        ? 'your weight held steady'
        : 'your weight trend ${c.trendKgPerWeek < 0 ? 'fell' : 'rose'} '
              '${kg(c.trendKgPerWeek.abs(), metric)} a week';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(S.radius),
        border: Border.all(color: C.tomato.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('GOAL CHECK-IN', style: T.caps.copyWith(color: C.tomato)),
          const SizedBox(height: 8),
          Text(
            'You burn about ${kcal(c.measured)} a day, not ${kcal(c.current)}.',
            style: T.heading.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Over ${c.loggedDays} fully logged days you averaged ${kcal(c.avgIntake)} kcal and '
            '$trend. That points to a ${higher ? 'higher' : 'lower'} maintenance than the '
            'formula guessed.',
            style: T.small.copyWith(color: C.ink2),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('New target ', style: T.small),
              Text(kcal(c.newTarget), style: T.heading),
              Text('  was ${kcal(s.targets.kcal)}', style: T.small),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Update goal',
                  onTap: () async {
                    await Store.i.acceptCheckIn(c);
                    if (context.mounted) {
                      showToast(context, 'Goal updated to ${kcal(Store.i.targets.kcal)} kcal.');
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                onTap: Store.i.snoozeCheckIn,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  child: Text('Not now', style: T.bodyStrong.copyWith(color: C.ink2)),
                ),
              ),
            ],
          ),
          if (s.profile.goal != Goal.maintain) ...[
            const SizedBox(height: 4),
            Text(
              'Keeps your ${kg(s.profile.paceKg, metric)} a week ${s.profile.goal == Goal.lose ? 'loss' : 'gain'} pace.',
              style: T.small.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
