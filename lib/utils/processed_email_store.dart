import 'package:shared_preferences/shared_preferences.dart';

class ProcessedEmailStore {
  static const String _kLastProcessedEpoch = 'last_processed_epoch_sec';
  static const String _kBackgroundRunning = 'bg_service_running';

  /// epoch seconds of last processed message (UTC)
  static Future<int> getLastProcessedEpochSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kLastProcessedEpoch) ?? 0;
  }

  static Future<void> setLastProcessedEpochSec(int epochSec) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastProcessedEpoch, epochSec);
  }

  /// store whether background job is registered
  static Future<void> setBackgroundRunning(bool running) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBackgroundRunning, running);
  }

  static Future<bool> isBackgroundRunning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBackgroundRunning) ?? false;
  }
}
