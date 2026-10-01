import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../ai/client.dart';

import '../../data/activity.dart';
import '../../data/inbox.dart';
import '../../data/log_queue.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../theme/tokens.dart';
import '../../ui/controls.dart';
import '../../ui/format.dart';
import '../../ui/buttons.dart';
import '../../ui/macro_bar.dart';
import '../../ui/nutrition_details.dart';
import '../../ui/ring.dart';
import '../../ui/week_strip.dart';
import '../log/review_screen.dart';
import 'check_in_card.dart';
import 'composer.dart';
import 'menu_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  /// Lets other tabs jump here with a day selected.
  static final day = ValueNotifier<DateTime>(dayOf(DateTime.now()));

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Activity.i.refresh();
    _drainQueue();
  }

  /// Reads logs saved while offline, now that we might be online.
  Future<void> _drainQueue() async {
    await Inbox.drain();
    final n = await LogQueue.process();
    if (n > 0 && mounted) {
      showToast(context, n == 1 ? 'Logged 1 saved meal.' : 'Logged $n saved meals.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Activity.i.refresh();
      _drainQueue();
    }
  }

  DateTime get _day => TodayScreen.day.value;
  bool get _isToday => _day == dayOf(DateTime.now());

  /// When something is logged for another day, keep the current clock time.
  DateTime get _logTime {
    final now = DateTime.now();
    return DateTime(_day.year, _day.month, _day.day, now.hour, now.minute);
  }

  void _open(Entry e) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen.edit(entry: e)));

  void _log(String text) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ReviewScreen.parse(text: text, at: _logTime),
    ),
  );

  Future<void> _photo(String caption) async {
    final source = await showPaperSheet<ImageSource>(
      context,
      (context) => Padding(
        padding: const EdgeInsets.fromLTRB(S.gutter, 16, S.gutter, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log from a photo', style: T.heading),
            const SizedBox(height: 4),
            Text(
              caption.isEmpty
                  ? 'Your AI model reads the plate; the numbers still come from the food tables.'
                  : 'Caption: “$caption”',
              style: T.small,
            ),
            const SizedBox(height: 8),
            RuledRow(
              label: 'Take a photo',
              leading: Icon(Icons.photo_camera_outlined, color: C.ink),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            RuledRow(
              label: 'Choose from gallery',
              leading: Icon(Icons.photo_library_outlined, color: C.ink),
              last: true,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, maxWidth: 1280, imageQuality: 80);
    } catch (_) {
      if (mounted) showToast(context, 'Couldn’t open the camera or gallery.');
      return;
    }
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewScreen.parse(
          text: caption,
          at: _logTime,
          photo: Photo(bytes, mime: file!.mimeType ?? 'image/jpeg'),
        ),
      ),
    );
  }

  Future<void> _quick(String title, List<FoodItem> items) async {
    final at = _logTime;
    final e = Entry(
      id: Store.newId(),
      at: at,
      meal: Meal.forTime(DateTime.now()),
      title: title,
      text: '',
      items: items,
    );
    await Store.i.putEntry(e);
    if (!mounted) return;
    showToast(
      context,
      'Logged $title · ${kcal(e.total.kcal)} kcal',
      action: 'Undo',
      onAction: () => Store.i.deleteEntry(e.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Store.i, TodayScreen.day, Activity.i]),
      builder: (context, _) {
        final s = Store.i;
        final targets = s.targets;
        final entries = s.entriesOn(_day);
        final total = s.totalOn(_day);
        final health = Activity.i.connected;
        final burned = health ? Activity.i.on(_day).activeKcal : 0.0;
        final budget = targets.kcal + (s.eatBack ? burned : 0);
        final left = budget - total.kcal;
        final streak = s.streak;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(S.gutter, 12, S.gutter, 24),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      Row(
                        children: [
                          Text('nomnom', style: T.brand),
                          const Spacer(),
                          if (streak > 0) _StreakPill(streak),
                        ],
                      ),
                      if (_isToday && s.checkIn != null) ...[
                        const SizedBox(height: 16),
                        CheckInCard(checkIn: s.checkIn!),
                      ],
                      const SizedBox(height: 16),
                      WeekStrip(
                        selected: _day,
                        hasLog: s.hasLog,
                        onSelect: (d) => TodayScreen.day.value = d,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          CalorieRing(
                            value: total.kcal,
                            goal: budget,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(end: left.abs()),
                                  duration: Motion.slow,
                                  curve: Motion.curve,
                                  builder: (context, v, _) => Text(
                                    kcal(v),
                                    style: T.title.copyWith(fontSize: 40, height: 1),
                                  ),
                                ),
                                Text(
                                  left >= 0 ? 'LEFT' : 'OVER',
                                  style: T.caps.copyWith(color: left >= 0 ? C.ink2 : C.tomato),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              children: [
                                _Stat('Eaten', kcal(total.kcal)),
                                _Stat('Goal', kcal(budget)),
                                if (health) ...[
                                  _Stat('Burned', kcal(burned)),
                                  _Stat('Steps', kcal(Activity.i.on(_day).steps), last: true),
                                ] else
                                  _Stat('Fibre', '${total.fiber.round()} g', last: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      MacroSplit(
                        values: [
                          MacroValue('Protein', total.protein, targets.protein, C.protein),
                          MacroValue('Carbs', total.carbs, targets.carbs, C.carbs),
                          MacroValue('Fat', total.fat, targets.fat, C.fat),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              [
                                if (total.micros[Micro.sugar] != null)
                                  'Sugar ${total.micros[Micro.sugar]!.round()} g',
                                if (total.micros[Micro.sodium] != null)
                                  'Sodium ${kcal(total.micros[Micro.sodium]!)} mg',
                              ].join(' · '),
                              style: T.small,
                            ),
                          ),
                          TextLink(
                            label: 'All nutrients',
                            onTap: entries.isEmpty
                                ? null
                                : () => showNutritionDetails(
                                    context,
                                    _isToday ? 'Today' : dayLabel(_day),
                                    [for (final e in entries) ...e.items],
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      MenuCard(
                        title: _isToday ? "Today's menu" : "${dayLabel(_day)}'s menu",
                        entries: entries,
                        goal: budget,
                        isToday: _isToday,
                        onTap: _open,
                        pending: s.pendingOn(_day),
                        yesterday: s.entriesOn(_day.subtract(const Duration(days: 1))),
                        onRepeat: (es) async {
                          final copies = await Store.i.copyTo(es, _day);
                          if (!context.mounted) return;
                          showToast(
                            context,
                            'Logged ${es.first.meal.label.toLowerCase()} again · '
                            '${kcal(copies.fold<double>(0, (s, e) => s + e.total.kcal))} kcal',
                            action: 'Undo',
                            onAction: () {
                              for (final c in copies) {
                                Store.i.deleteEntry(c.id);
                              }
                            },
                          );
                        },
                        onTapPending: (p) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReviewScreen.parse(text: p.text, at: p.at, pendingId: p.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Composer(onSubmit: _log, onQuick: _quick, onPhoto: _photo),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: last ? null : Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Text(label, style: T.small),
        const Spacer(),
        Text(value, style: T.bodyStrong),
      ],
    ),
  );
}

class _StreakPill extends StatelessWidget {
  const _StreakPill(this.days);

  final int days;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      border: Border.all(color: C.ink),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_outlined, size: 15, color: C.tomato),
        const SizedBox(width: 4),
        Text(days == 1 ? '1 day' : '$days days', style: T.small.copyWith(color: C.ink)),
      ],
    ),
  );
}
