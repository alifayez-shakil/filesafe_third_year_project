import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  /// Returns `true` if the device has an active internet connection.
  static Future<bool> isOnline() async {
    final results = await Connectivity().checkConnectivity();
    // connectivity_plus v4+ returns a List<ConnectivityResult>
    return !results.contains(ConnectivityResult.none);
  }

  /// A stream that emits `true` when online, `false` otherwise.
  static Stream<bool> get onlineStream => Connectivity().onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
}
