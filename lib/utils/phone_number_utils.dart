import '../constants/country_dial_codes.dart';

class PhoneNumberParts {
  final String dialCode;
  final String nationalNumber;

  const PhoneNumberParts({
    required this.dialCode,
    required this.nationalNumber,
  });
}

class PhoneNumberUtils {
  static final RegExp _nonDigitRegex = RegExp(r'[^0-9]');

  static String sanitizeNationalNumber(String input) {
    return input.replaceAll(_nonDigitRegex, '');
  }

  static bool isValidNationalNumber(String input) {
    final digits = sanitizeNationalNumber(input);
    return digits.length >= 6 && digits.length <= 15;
  }

  static bool isValidNationalNumberForDialCode(String input, String dialCode) {
    final digits = sanitizeNationalNumber(input);
    final expectedLength = CountryDialCodes.getPhoneNumberLength(dialCode);
    if (expectedLength == null) {
      // Fallback to general validation if country not found
      return isValidNationalNumber(input);
    }
    return digits.length == expectedLength;
  }

  static String _normalizeDialCode(String dialCode) {
    final digits = dialCode.replaceAll(_nonDigitRegex, '');
    if (digits.isEmpty) {
      return CountryDialCodes.defaultDialCode;
    }
    return '+$digits';
  }

  static String formatForBackend(String dialCode, String nationalNumber) {
    final normalizedDialCode = _normalizeDialCode(dialCode);
    var cleanedNational = sanitizeNationalNumber(nationalNumber);
    if (cleanedNational.isEmpty) return normalizedDialCode;

    // Remove only leading zeroes that act as trunk prefixes
    cleanedNational = cleanedNational.replaceFirst(RegExp(r'^0+'), '');
    if (cleanedNational.isEmpty) {
      cleanedNational = '0';
    }

    return '$normalizedDialCode$cleanedNational';
  }

  static PhoneNumberParts splitPhoneNumber(String? fullNumber) {
    if (fullNumber == null || fullNumber.trim().isEmpty) {
      return PhoneNumberParts(
        dialCode: CountryDialCodes.defaultDialCode,
        nationalNumber: '',
      );
    }

    var working = fullNumber.trim();
    if (working.startsWith('00')) {
      working = '+${working.substring(2)}';
    } else if (!working.startsWith('+')) {
      working = working;
    }

    if (working.startsWith('+')) {
      for (final info in CountryDialCodes.dialCodesSortedByLengthDesc) {
        if (working.startsWith(info.dialCode)) {
          final remainder = working.substring(info.dialCode.length);
          return PhoneNumberParts(
            dialCode: info.dialCode,
            nationalNumber: sanitizeNationalNumber(remainder),
          );
        }
      }

      return PhoneNumberParts(
        dialCode: CountryDialCodes.defaultDialCode,
        nationalNumber: sanitizeNationalNumber(working.substring(1)),
      );
    }

    return PhoneNumberParts(
      dialCode: CountryDialCodes.defaultDialCode,
      nationalNumber: sanitizeNationalNumber(working),
    );
  }
}

