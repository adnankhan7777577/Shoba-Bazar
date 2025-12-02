import '../constants/app_texts.dart';

class NetworkErrorUtils {
  /// Check if an error message indicates a network connectivity issue
  static bool isNetworkError(String error) {
    final lowerError = error.toLowerCase();
    return lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout') ||
        lowerError.contains('socket') ||
        lowerError.contains('failed host lookup') ||
        lowerError.contains('no internet') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('connection reset') ||
        lowerError.contains('connection closed') ||
        lowerError.contains('unable to resolve host') ||
        lowerError.contains('no address associated with hostname');
  }

  /// Get a user-friendly network error message
  static String getNetworkErrorMessage(String? originalError) {
    if (originalError != null && isNetworkError(originalError)) {
      return AppTexts.errorNoNetwork;
    }
    return originalError ?? AppTexts.errorGeneral;
  }
}

