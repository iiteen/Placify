import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;

  static Future<File> _getLogFile() async {
    if (_logFile != null) return _logFile!;

    final Directory? dir = await getExternalStorageDirectory();
    final String path = dir!.path;
    _logFile = File('$path/app.log');

    if (!await _logFile!.exists()) {
      await _logFile!.create(recursive: true);
    }

    return _logFile!;
  }

  static Future<void> log(String message) async {
    try {
      final ts = DateTime.now().toIso8601String();
      final line = '[$ts] $message';

      if (kDebugMode) {
        debugPrint(line);
      }

      final file = await _getLogFile();
      await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
    } catch (e, stack) {
      // Logging must NEVER crash your app
      debugPrint('Logger error: $e');
      debugPrint(stack.toString());
    }
  }
}
