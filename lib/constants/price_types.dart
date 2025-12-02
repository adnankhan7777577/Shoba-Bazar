class PriceTypes {
  // Currency data structure: {code, displayName}
  static const List<Map<String, String>> currencies = [
    {'code': 'PKR', 'displayName': 'PKR'},
    {'code': 'USD', 'displayName': 'Dollar'},
    {'code': 'EUR', 'displayName': 'Euro'},
    {'code': 'GBP', 'displayName': 'Pound'},
    {'code': 'AED', 'displayName': 'Dirham'},
    {'code': 'SAR', 'displayName': 'Riyal'},
    {'code': 'CAD', 'displayName': 'Dollar (CAD)'},
    {'code': 'AUD', 'displayName': 'Dollar (AUD)'},
  ];

  // Get all currency codes
  static List<String> get allCurrencyCodes => 
      currencies.map((e) => e['code']!).toList();

  // Get all display names
  static List<String> get allDisplayNames => 
      currencies.map((e) => e['displayName']!).toList();

  // Get currency code from display name
  static String? getCurrencyCode(String displayName) {
    try {
      return currencies.firstWhere(
        (currency) => currency['displayName'] == displayName,
      )['code'];
    } catch (e) {
      return null;
    }
  }

  // Get display name from currency code
  static String? getDisplayName(String currencyCode) {
    try {
      return currencies.firstWhere(
        (currency) => currency['code'] == currencyCode,
      )['displayName'];
    } catch (e) {
      return null;
    }
  }
}

