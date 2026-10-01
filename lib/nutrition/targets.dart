import '../data/models.dart';

/// Daily targets derived from a profile.
class Targets {
  const Targets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.maintenance,
    required this.suggested,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Measured from logs when accepted, else Mifflin–St Jeor BMR × activity.
  final double maintenance;

  /// What we'd recommend before any custom override.
  final double suggested;

  static Targets of(Profile p) {
    final maintenance = p.learnedMaintenance ?? tdee(p);
    final suggested = suggestedKcal(p, maintenance);
    final kcal = (p.customKcal ?? suggested).toDouble();
    return Targets(
      kcal: kcal,
      protein: kcal * p.macros.protein / 4,
      carbs: kcal * p.macros.carbs / 4,
      fat: kcal * p.macros.fat / 9,
      maintenance: maintenance,
      suggested: suggested.toDouble(),
    );
  }
}

double bmr(Profile p) {
  final a = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
  return p.sex == Sex.male ? a + 5 : a - 161;
}

double tdee(Profile p) => bmr(p) * p.activity;

/// 1 kg of body fat ≈ 7700 kcal. Never suggest below a safe floor.
int suggestedKcal(Profile p, [double? maintenance]) {
  final m = maintenance ?? tdee(p);
  final daily = p.paceKg * 7700 / 7;
  final raw = switch (p.goal) {
    Goal.lose => m - daily,
    Goal.maintain => m,
    Goal.gain => m + daily,
  };
  final floor = p.sex == Sex.male ? 1500.0 : 1200.0;
  return ((raw < floor ? floor : raw) / 10).round() * 10;
}

const activityLevels = <(double, String, String)>[
  (1.2, 'Sedentary', 'Desk job, little exercise'),
  (1.375, 'Light', 'Exercise 1–3 days a week'),
  (1.55, 'Moderate', 'Exercise 3–5 days a week'),
  (1.725, 'Active', 'Hard exercise 6–7 days'),
  (1.9, 'Athlete', 'Physical job or twice-a-day training'),
];

String activityLabel(double f) =>
    activityLevels.reduce((a, b) => (a.$1 - f).abs() < (b.$1 - f).abs() ? a : b).$2;

String kg(double v, bool metric) =>
    metric ? '${formatNum(_round1(v))} kg' : '${formatNum(_round1(v * 2.20462))} lb';

String cm(double v, bool metric) {
  if (metric) return '${v.round()} cm';
  final inches = (v / 2.54).round();
  return '${inches ~/ 12}′${inches % 12}″';
}

double _round1(double v) => (v * 10).roundToDouble() / 10;

double bmiOf(double kgValue, double heightCm) =>
    heightCm <= 0 ? 0 : kgValue / ((heightCm / 100) * (heightCm / 100));

/// WHO bands. South Asian countries use the lower Asian cut-offs, where
/// health risk rises at a lower BMI.
const _asianCutoffs = {
  'IN',
  'PK',
  'BD',
  'LK',
  'NP',
  'SG',
  'MY',
  'ID',
  'PH',
  'TH',
  'VN',
  'CN',
  'JP',
  'KR',
};

String bmiBand(double bmi, String country) {
  final asian = _asianCutoffs.contains(country);
  if (bmi < 18.5) return 'Underweight';
  if (bmi < (asian ? 23 : 25)) return 'Healthy range';
  if (bmi < (asian ? 27.5 : 30)) return 'Overweight';
  return 'Obese range';
}

String bmiLabel(Profile p, [double? kgValue]) {
  final b = bmiOf(kgValue ?? p.weightKg, p.heightCm);
  return 'BMI ${b.toStringAsFixed(1)} · ${bmiBand(b, p.country)}';
}
