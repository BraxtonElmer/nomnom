import 'package:intl/intl.dart';

import '../data/models.dart';

final _int = NumberFormat.decimalPattern();

String kcal(num v) => _int.format(v.round());

String macros(Nutrients n) =>
    '${n.protein.round()}p · ${n.carbs.round()}c · ${n.fat.round()}f';

String time(DateTime t) => DateFormat.jm().format(t).replaceAll(' ', '').toLowerCase();

String dayLabel(DateTime d) {
  final today = dayOf(DateTime.now());
  final diff = today.difference(dayOf(d)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat.EEEE().format(d);
  return DateFormat('EEE, d MMM').format(d);
}
