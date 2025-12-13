import 'package:flutter/foundation.dart';

import 'gmail_service.dart';
import 'calendar_service.dart';

class PermissionService {
  /// Called on app startup
  static Future<void> ensurePermissions() async {
    var ok = await _verifySilently();
    if (ok) return;

    debugPrint("⚠ Couldnt get permissions");
  }

  /// Silent check without UI
  static Future<bool> _verifySilently() async {
    try {
      final gmail = GmailService();
      final calendar = CalendarService();

      await calendar.initCalendar();

      return await gmail.signIn();
    } catch (_) {
      return false;
    }
  }
}