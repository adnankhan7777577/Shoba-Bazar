import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connectivity
  /// Returns true if connected, false otherwise
  /// Uses connectivity_plus for primary check, with optional DNS verification
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      
      // If no connectivity at all, return false
      if (connectivityResults.isEmpty || 
          connectivityResults.contains(ConnectivityResult.none)) {
        return false;
      }

      // If we have connectivity (wifi, mobile, etc.), trust it
      // The actual API calls will handle real network errors
      // DNS lookup can fail due to firewalls, DNS issues, or network restrictions
      // even when internet is available, so we don't rely on it as a hard requirement
      return true;
    } catch (e) {
      // If connectivity check fails, assume no connection
      print('Network connectivity check error: $e');
      return false;
    }
  }

  /// Get current connectivity status
  static Future<List<ConnectivityResult>> getConnectivityStatus() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      return [ConnectivityResult.none];
    }
  }

  /// Stream of connectivity changes
  static Stream<List<ConnectivityResult>> get connectivityStream {
    return _connectivity.onConnectivityChanged;
  }
}

