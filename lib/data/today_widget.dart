import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../theme/tokens.dart';
import '../ui/format.dart';
import '../ui/macro_bar.dart';
import '../ui/ring.dart';
import 'activity.dart';
import 'store.dart';

/// The home-screen widget: today's ring as a small Paper card. Drawn with
/// the app's own widgets into an image, which the Android widget shows.
class TodayWidget {
  static Timer? _debounce;
  static bool _started = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void start() {
    if (!supported || _started) return;
    _started = true;
    Store.i.addListener(_changed);
    Activity.i.addListener(_changed);
    _changed();
  }

  static void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), refresh);
  }

  static Future<void> refresh() async {
    if (!supported || !Store.i.onboarded) return;
    try {
      await HomeWidget.renderFlutterWidget(
        const TodayCard(),
        key: 'today',
        logicalSize: const Size(340, 156),
      );
      await HomeWidget.updateWidget(qualifiedAndroidName: 'app.nomnom.nomnom.TodayWidget');
    } catch (e) {
      debugPrint('Widget not updated: $e');
    }
  }
}

class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final t = s.targets;
    final total = s.totalOn(DateTime.now());
    final burned = Activity.i.connected && s.eatBack ? Activity.i.on(DateTime.now()).activeKcal : 0.0;
    final goal = t.kcal + burned;
    final left = goal - total.kcal;
    return MediaQuery(
      data: const MediaQueryData(),
      child: Container(
        width: 340,
        height: 156,
        padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            CalorieRing(
              value: total.kcal,
              goal: goal,
              size: 120,
              stroke: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(kcal(left.abs()), style: T.title.copyWith(fontSize: 32, height: 1)),
                  Text(
                    left >= 0 ? 'LEFT' : 'OVER',
                    style: T.caps.copyWith(color: left >= 0 ? C.ink2 : C.tomato),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('nomnom', style: T.brand.copyWith(fontSize: 20)),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: kcal(total.kcal), style: T.bodyStrong),
                        TextSpan(text: ' of ${kcal(goal)} kcal', style: T.small),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        for (final (i, (v, c)) in [
                          (total.protein * 4, C.protein),
                          (total.carbs * 4, C.carbs),
                          (total.fat * 9, C.fat),
                        ].indexed) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            flex: total.kcal <= 0
                                ? 1
                                : (v / total.kcal * 100).round().clamp(1, 100),
                            child: Container(
                              decoration: BoxDecoration(
                                color: total.kcal <= 0 ? C.line : c,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Dot(C.protein, size: 6),
                      Text('${total.protein.round()}p  ', style: T.small.copyWith(fontSize: 12)),
                      Dot(C.carbs, size: 6),
                      Text('${total.carbs.round()}c  ', style: T.small.copyWith(fontSize: 12)),
                      Dot(C.fat, size: 6),
                      Text('${total.fat.round()}f', style: T.small.copyWith(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
