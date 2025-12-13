import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';


class AppLogger {
  static File? _logFile;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/app.log');
  }

  static Future<void> log(String message) async {
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] $message\n';

    // Console (during dev)
    // ignore: avoid_print
    debugPrint(line);

    if (_logFile != null) {
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    }

  }
}
