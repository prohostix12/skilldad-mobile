/// A dialing-code entry used by the register screen's country picker.
class CountryCode {
  const CountryCode({required this.code, required this.name, required this.flag});

  final String code;
  final String name;
  final String flag;
}

/// Same country list used on the web app's Register page (client/src/pages/
/// Register.jsx), so phone validation stays consistent across platforms.
const List<CountryCode> kCountryCodes = [
  CountryCode(code: '+91', name: 'India', flag: '🇮🇳'),
  CountryCode(code: '+1', name: 'USA/Canada', flag: '🇺🇸'),
  CountryCode(code: '+44', name: 'UK', flag: '🇬🇧'),
  CountryCode(code: '+971', name: 'UAE', flag: '🇦🇪'),
  CountryCode(code: '+61', name: 'Australia', flag: '🇦🇺'),
  CountryCode(code: '+65', name: 'Singapore', flag: '🇸🇬'),
  CountryCode(code: '+49', name: 'Germany', flag: '🇩🇪'),
  CountryCode(code: '+33', name: 'France', flag: '🇫🇷'),
  CountryCode(code: '+81', name: 'Japan', flag: '🇯🇵'),
  CountryCode(code: '+86', name: 'China', flag: '🇨🇳'),
  CountryCode(code: '+966', name: 'Saudi Arabia', flag: '🇸🇦'),
  CountryCode(code: '+974', name: 'Qatar', flag: '🇶🇦'),
  CountryCode(code: '+965', name: 'Kuwait', flag: '🇰🇼'),
  CountryCode(code: '+968', name: 'Oman', flag: '🇴🇲'),
  CountryCode(code: '+973', name: 'Bahrain', flag: '🇧🇭'),
  CountryCode(code: '+20', name: 'Egypt', flag: '🇪🇬'),
  CountryCode(code: '+27', name: 'South Africa', flag: '🇿🇦'),
  CountryCode(code: '+234', name: 'Nigeria', flag: '🇳🇬'),
  CountryCode(code: '+254', name: 'Kenya', flag: '🇰🇪'),
  CountryCode(code: '+60', name: 'Malaysia', flag: '🇲🇾'),
  CountryCode(code: '+66', name: 'Thailand', flag: '🇹🇭'),
  CountryCode(code: '+62', name: 'Indonesia', flag: '🇮🇩'),
  CountryCode(code: '+63', name: 'Philippines', flag: '🇵🇭'),
  CountryCode(code: '+84', name: 'Vietnam', flag: '🇻🇳'),
  CountryCode(code: '+82', name: 'South Korea', flag: '🇰🇷'),
  CountryCode(code: '+7', name: 'Russia', flag: '🇷🇺'),
  CountryCode(code: '+39', name: 'Italy', flag: '🇮🇹'),
  CountryCode(code: '+34', name: 'Spain', flag: '🇪🇸'),
  CountryCode(code: '+31', name: 'Netherlands', flag: '🇳🇱'),
  CountryCode(code: '+41', name: 'Switzerland', flag: '🇨🇭'),
  CountryCode(code: '+46', name: 'Sweden', flag: '🇸🇪'),
  CountryCode(code: '+47', name: 'Norway', flag: '🇳🇴'),
  CountryCode(code: '+45', name: 'Denmark', flag: '🇩🇰'),
  CountryCode(code: '+358', name: 'Finland', flag: '🇫🇮'),
  CountryCode(code: '+353', name: 'Ireland', flag: '🇮🇪'),
  CountryCode(code: '+351', name: 'Portugal', flag: '🇵🇹'),
  CountryCode(code: '+30', name: 'Greece', flag: '🇬🇷'),
  CountryCode(code: '+90', name: 'Turkey', flag: '🇹🇷'),
  CountryCode(code: '+55', name: 'Brazil', flag: '🇧🇷'),
  CountryCode(code: '+52', name: 'Mexico', flag: '🇲🇽'),
  CountryCode(code: '+54', name: 'Argentina', flag: '🇦🇷'),
  CountryCode(code: '+56', name: 'Chile', flag: '🇨🇱'),
  CountryCode(code: '+57', name: 'Colombia', flag: '🇨🇴'),
  CountryCode(code: '+51', name: 'Peru', flag: '🇵🇪'),
  CountryCode(code: '+92', name: 'Pakistan', flag: '🇵🇰'),
  CountryCode(code: '+880', name: 'Bangladesh', flag: '🇧🇩'),
  CountryCode(code: '+94', name: 'Sri Lanka', flag: '🇱🇰'),
  CountryCode(code: '+977', name: 'Nepal', flag: '🇳🇵'),
];

/// Exact national mobile-number digit count (excluding the country code) for
/// the countries above where the length is fixed. Countries not listed here
/// fall back to a generic 7-14 digit range check. Mirrors
/// client/src/pages/Register.jsx's `countryPhoneLengths`.
const Map<String, int> kCountryPhoneLengths = {
  '+91': 10, // India
  '+1': 10, // USA/Canada
  '+44': 10, // UK
  '+971': 9, // UAE
  '+61': 9, // Australia
  '+65': 8, // Singapore
  '+966': 9, // Saudi Arabia
  '+974': 8, // Qatar
  '+965': 8, // Kuwait
  '+968': 8, // Oman
  '+973': 8, // Bahrain
  '+92': 10, // Pakistan
  '+880': 10, // Bangladesh
  '+94': 9, // Sri Lanka
  '+977': 10, // Nepal
};

/// Catches obviously-fake placeholder numbers that pass a plain length check
/// (e.g. 1234567890, 0000000000, 9876543210) - a real number is never a
/// simple run of identical or consecutive digits.
bool isSequentialOrRepeated(String digits) {
  if (digits.isEmpty) return false;
  if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return true;

  var ascending = true;
  var descending = true;
  for (var i = 1; i < digits.length; i++) {
    final prev = int.parse(digits[i - 1]);
    final curr = int.parse(digits[i]);
    if (curr != (prev + 1) % 10) ascending = false;
    if (curr != (prev + 9) % 10) descending = false;
  }
  return ascending || descending;
}
