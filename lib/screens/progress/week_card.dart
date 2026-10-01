import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../ai/client.dart';
import '../../data/keys.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../nutrition/week_summary.dart';
import '../../theme/tokens.dart';

/// Last week's recap. Shown from the numbers straight away; when AI is set
/// up, worded once by the user's model and kept for that week.
class WeekCard extends StatefulWidget {
  const WeekCard({super.key, this.today});

  /// For tests.
  final DateTime? today;

  @override
  State<WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<WeekCard> {
  WeekSummary? _ai;
  bool _asked = false;

  DateTime get _monday =>
      addDays(weekStart(widget.today ?? DateTime.now()), -7);

  WeekStats? get _stats {
    final s = Store.i;
    return WeekStats.compute(
      start: _monday,
      entriesOn: s.entriesOn,
      targets: s.targets,
      weights: s.weights,
    );
  }

  @override
  void initState() {
    super.initState();
    final cached = Store.i.weekRecap(_monday);
    if (cached != null) {
      try {
        _ai = WeekSummary.fromJson(Map<String, dynamic>.from(jsonDecode(cached)));
      } catch (_) {}
    }
    if (_ai == null) _write();
  }

  Future<void> _write() async {
    final s = Store.i;
    final stats = _stats;
    if (_asked || stats == null || !s.ai.ready || s.keyMissing) return;
    _asked = true;
    final monday = _monday;
    try {
      final key = await KeyVault.read(s.ai.provider);
      final w = await WeekSummary.write(
        AiClient.of(s.ai, key),
        stats,
        metric: s.profile.metric,
      );
      await s.putWeekRecap(monday, jsonEncode(w.toJson()));
      if (mounted) setState(() => _ai = w);
    } on AiException catch (e) {
      debugPrint('Recap not written: ${e.message}');
    } catch (e) {
      debugPrint('Recap not written: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();
    final w = _ai ?? WeekSummary.plain(stats, metric: Store.i.profile.metric);
    final end = addDays(stats.start, 6);
    final range = stats.start.month == end.month
        ? '${stats.start.day}–${DateFormat('d MMM').format(end)}'
        : '${DateFormat('d MMM').format(stats.start)} – ${DateFormat('d MMM').format(end)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(S.radius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('LAST WEEK · ${range.toUpperCase()}', style: T.caps),
          const SizedBox(height: 8),
          Text(w.headline, style: T.heading),
          const SizedBox(height: 10),
          for (final p in w.points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: C.ink3, shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(child: Text(p, style: T.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
