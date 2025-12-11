import 'package:shared_preferences/shared_preferences.dart';

class ProcessedEmailStore {
  static const String key = "last_processed_email_epoch";

  static Future<int> getLastProcessedEpochSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  static Future<void> saveLastProcessedEpochSec(int epoch) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, epoch);
  }
}
