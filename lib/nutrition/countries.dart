/// Countries offered at onboarding. The name goes into the AI prompt so
/// portions and recipes match local food; IN also gets the dish table.
const countries = <String, String>{
  'IN': 'India',
  'US': 'United States',
  'GB': 'United Kingdom',
  'CA': 'Canada',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'IE': 'Ireland',
  'PK': 'Pakistan',
  'BD': 'Bangladesh',
  'LK': 'Sri Lanka',
  'NP': 'Nepal',
  'AE': 'United Arab Emirates',
  'SA': 'Saudi Arabia',
  'SG': 'Singapore',
  'MY': 'Malaysia',
  'ID': 'Indonesia',
  'PH': 'Philippines',
  'TH': 'Thailand',
  'VN': 'Vietnam',
  'CN': 'China',
  'JP': 'Japan',
  'KR': 'South Korea',
  'DE': 'Germany',
  'FR': 'France',
  'IT': 'Italy',
  'ES': 'Spain',
  'NL': 'Netherlands',
  'BR': 'Brazil',
  'MX': 'Mexico',
  'NG': 'Nigeria',
  'KE': 'Kenya',
  'ZA': 'South Africa',
  'EG': 'Egypt',
  'TR': 'Turkey',
};

String countryName(String code) => countries[code] ?? code;

/// Countries that use imperial body units by default.
const imperialByDefault = {'US', 'GB'};
