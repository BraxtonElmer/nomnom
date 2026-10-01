/// Dish tables by cuisine. Every table is searched for everyone, so a
/// Chinese takeaway in Mumbai or a curry in London still matches; the
/// countries only give a small nudge to the food that's local.
class Cuisine {
  const Cuisine(this.id, this.label, this.countries);

  final String id;
  final String label;
  final Set<String> countries;

  String get asset => 'assets/data/dishes/$id.json';
}

const cuisines = <Cuisine>[
  Cuisine('indian', 'Indian', {'IN', 'NP', 'BD', 'LK', 'PK'}),
  Cuisine('south-asian', 'South Asian', {'PK', 'BD', 'LK', 'NP', 'IN'}),
  Cuisine('chinese', 'Chinese', {'CN', 'SG', 'MY', 'HK', 'TW'}),
  Cuisine('japanese', 'Japanese', {'JP'}),
  Cuisine('korean', 'Korean', {'KR'}),
  Cuisine('thai', 'Thai', {'TH'}),
  Cuisine('vietnamese', 'Vietnamese', {'VN'}),
  Cuisine('southeast-asian', 'Southeast Asian', {'ID', 'MY', 'SG', 'PH'}),
  Cuisine('italian', 'Italian', {'IT'}),
  Cuisine('european', 'European', {'FR', 'DE', 'ES', 'NL', 'IT'}),
  Cuisine('british', 'British', {'GB', 'IE', 'AU', 'NZ'}),
  Cuisine('american', 'American', {'US', 'CA'}),
  Cuisine('mexican', 'Mexican', {'MX', 'US'}),
  Cuisine('latin-american', 'Latin American', {'BR', 'MX'}),
  Cuisine('middle-eastern', 'Middle Eastern', {'AE', 'SA', 'EG', 'TR'}),
  Cuisine('african', 'African', {'NG', 'KE', 'ZA', 'EG'}),
];

Cuisine? cuisineById(String? id) => cuisines.where((c) => c.id == id).firstOrNull;
