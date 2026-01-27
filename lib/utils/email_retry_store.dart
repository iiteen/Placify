import 'package:shared_preferences/shared_preferences.dart';

class EmailRetryStore {
  static Future<int> getRetryCount(String emailId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("retry_$emailId") ?? 0;
  }

  static Future<void> incrementRetry(String emailId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = "retry_$emailId";
    prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  static Future<void> clear(String emailId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove("retry_$emailId");
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    final keysToRemove = prefs
        .getKeys()
        .where((key) => key.startsWith('retry_'))
        .toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }
}
