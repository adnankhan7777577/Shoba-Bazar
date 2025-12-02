class CountryDialInfo {
  final String country;
  final String dialCode;
  final int phoneNumberLength;

  const CountryDialInfo({
    required this.country,
    required this.dialCode,
    required this.phoneNumberLength,
  });
}

class CountryDialCodes {
  static const String defaultDialCode = '+92';

  static const List<CountryDialInfo> dialCodes = [
    CountryDialInfo(country: 'Pakistan', dialCode: '+92', phoneNumberLength: 10),
    CountryDialInfo(country: 'United Arab Emirates', dialCode: '+971', phoneNumberLength: 9),
    CountryDialInfo(country: 'Saudi Arabia', dialCode: '+966', phoneNumberLength: 9),
    CountryDialInfo(country: 'India', dialCode: '+91', phoneNumberLength: 10),
    CountryDialInfo(country: 'Bangladesh', dialCode: '+880', phoneNumberLength: 10),
    CountryDialInfo(country: 'Afghanistan', dialCode: '+93', phoneNumberLength: 9),
    CountryDialInfo(country: 'United States', dialCode: '+1', phoneNumberLength: 10),
    CountryDialInfo(country: 'United Kingdom', dialCode: '+44', phoneNumberLength: 10),
    CountryDialInfo(country: 'Canada', dialCode: '+1', phoneNumberLength: 10),
    CountryDialInfo(country: 'Australia', dialCode: '+61', phoneNumberLength: 9),
    CountryDialInfo(country: 'China', dialCode: '+86', phoneNumberLength: 11),
    CountryDialInfo(country: 'Japan', dialCode: '+81', phoneNumberLength: 10),
    CountryDialInfo(country: 'South Korea', dialCode: '+82', phoneNumberLength: 10),
    CountryDialInfo(country: 'Turkey', dialCode: '+90', phoneNumberLength: 10),
    CountryDialInfo(country: 'Germany', dialCode: '+49', phoneNumberLength: 10),
    CountryDialInfo(country: 'France', dialCode: '+33', phoneNumberLength: 9),
    CountryDialInfo(country: 'Italy', dialCode: '+39', phoneNumberLength: 10),
    CountryDialInfo(country: 'Spain', dialCode: '+34', phoneNumberLength: 9),
    CountryDialInfo(country: 'Netherlands', dialCode: '+31', phoneNumberLength: 9),
    CountryDialInfo(country: 'Russia', dialCode: '+7', phoneNumberLength: 10),
    CountryDialInfo(country: 'Malaysia', dialCode: '+60', phoneNumberLength: 9),
  ];

  static String dialCodeForCountry(String? country) {
    if (country == null) return defaultDialCode;
    final match = dialCodes.firstWhere(
      (info) => info.country.toLowerCase() == country.toLowerCase(),
      orElse: () => const CountryDialInfo(country: 'Default', dialCode: defaultDialCode, phoneNumberLength: 10),
    );
    return match.dialCode;
  }

  static int? getPhoneNumberLength(String dialCode) {
    final info = findByDialCode(dialCode);
    return info?.phoneNumberLength;
  }

  static List<CountryDialInfo> get dialCodesSortedByLengthDesc {
    final codes = List<CountryDialInfo>.from(dialCodes);
    codes.sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    return codes;
  }

  static CountryDialInfo? findByDialCode(String dialCode) {
    for (final info in dialCodes) {
      if (info.dialCode == dialCode) {
        return info;
      }
    }
    return null;
  }
}

