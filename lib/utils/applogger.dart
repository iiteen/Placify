import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static File? _logFile;
  static final Queue<String> _logQueue = Queue();
  static bool _isWriting = false;

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
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts] $message';

    if (kDebugMode) {
      debugPrint(line);
    }

    _logQueue.add(line);
    _processQueue();
  }

  static void _processQueue() async {
    if (_isWriting || _logQueue.isEmpty) return;
    _isWriting = true;

    try {
      final file = await _getLogFile();

      while (_logQueue.isNotEmpty) {
        final line = _logQueue.removeFirst();
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      }
    } catch (e, stack) {
      debugPrint('Logger error: $e');
      debugPrint(stack.toString());
    } finally {
      _isWriting = false;
    }
  }

  static Future<void> flush({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while ((_isWriting || _logQueue.isNotEmpty) &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
}
