import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import 'gmail_service.dart';
import 'gemini_parser.dart';
import 'role_sync_service.dart';
import '../utils/processed_email_store.dart';

class BackgroundService {
  static const String _taskUniqueName = "placement_email_worker";
  static const String _taskImmediate = "placement_email_worker_now";

  /// Initialize WorkManager callback dispatcher. Must be called once in main().
  static Future<void> initialize() async {
    Workmanager().initialize(
      callbackDispatcher, // <- top-level function
    );

    debugPrint("⚙ Workmanager initialized.");
  }

  /// Start periodic task
  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskUniqueName,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await ProcessedEmailStore.setBackgroundRunning(true);
    debugPrint("🔁 Background periodic task scheduled.");
  }

  /// Trigger one-off task immediately
  static Future<void> triggerNow() async {
    await Workmanager().registerOneOffTask(
      _taskImmediate,
      _taskImmediate,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    debugPrint("🚀 Immediate background task triggered.");
  }

  /// Stop periodic task
  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_taskUniqueName);
    await ProcessedEmailStore.setBackgroundRunning(false);
    debugPrint("🛑 Background job cancelled.");
  }

  static Future<bool> isRunning() => ProcessedEmailStore.isBackgroundRunning();
}

/// Rate limiter for Gemini API calls
class GeminiRateLimiter {
  final int maxRequestsPerMinute;
  final Queue<DateTime> _queue = Queue();

  GeminiRateLimiter({required this.maxRequestsPerMinute});

  Future<void> acquire() async {
    final now = DateTime.now();

    while (_queue.isNotEmpty && now.difference(_queue.first).inSeconds >= 60) {
      _queue.removeFirst();
    }

    if (_queue.length >= maxRequestsPerMinute) {
      final wait = 60 - now.difference(_queue.first).inSeconds + 1;
      debugPrint("⏳ Rate limit hit — waiting $wait sec");
      await Future.delayed(Duration(seconds: wait));
    }

    _queue.addLast(DateTime.now());
  }
}

/// ---- TOP-LEVEL callback dispatcher ----
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("📬 Background job started: $task");

      final gmailService = GmailService();
      final rateLimiter = GeminiRateLimiter(maxRequestsPerMinute: 5);

      final parser = await GeminiParser.createFromPrefs();
      if (parser == null) {
        debugPrint("❌ GeminiParser missing API key. Skipping.");
        return Future.value(true);
      }

      final roleSync = RoleSyncService();

      final signedIn = await gmailService.signIn();
      if (!signedIn) {
        debugPrint("❌ Gmail background sign-in failed.");
        return Future.value(true);
      }

      // sliding window
      int lastEpoch = await ProcessedEmailStore.getLastProcessedEpochSec();
      if (lastEpoch == 0) {
        lastEpoch =
            DateTime.now()
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch ~/
            1000;
        debugPrint("🕒 First run → fetching last 2 days.");
      }

      const baseQuery =
          'from:channeli.img@iitr.ac.in subject:("Submission Of Biodata" OR "Submission of Bio data")';

      List<gmail.Message> msgs = [];

      try {
        msgs = await gmailService.fetchMessagesSince(
          baseQuery: baseQuery,
          afterEpochSeconds: lastEpoch,
          pageSize: 50,
        );
      } catch (e) {
        debugPrint("⚠ fetchMessagesSince failed → fallback: $e");
        msgs = await gmailService.searchAndFetchMetadata(
          query: '$baseQuery after:$lastEpoch',
          maxResults: 50,
        );
      }

      if (msgs.isEmpty) {
        debugPrint("📭 No new messages found.");
        return Future.value(true);
      }

      // Gmail returns newest → oldest
      msgs = msgs.reversed.toList();
      debugPrint("🔄 Processing ${msgs.length} messages (Oldest → Newest)");

      int maxEpochSeen = lastEpoch;

      for (var m in msgs) {
        try {
          if (m.id == null) continue;
          final id = m.id!;
          await rateLimiter.acquire();

          final meta = await gmailService.getMessageMetadata(id);
          if (meta == null) continue;

          final currentEpoch = (_internalMillis(meta) / 1000).floor();

          String subject = "(no subject)";
          String dateHeader = DateTime.now().toIso8601String();

          for (final h in meta.payload?.headers ?? const []) {
            final name = (h.name ?? '').toLowerCase();
            if (name == 'subject') subject = h.value ?? subject;
            if (name == 'date') dateHeader = h.value ?? dateHeader;
          }

          final body = await gmailService.getFullMessageBody(id);
          if (body == null || body.trim().isEmpty) continue;

          debugPrint(
            "📧 [${DateTime.fromMillisecondsSinceEpoch(currentEpoch * 1000)}] $subject\n $body",
          );

          final parsedStr = await parser.parseEmail(
            subject: subject,
            body: body,
            emailReceivedDateTime: dateHeader,
          );

          debugPrint(parsedStr);

          dynamic parsedJson;
          try {
            parsedJson = jsonDecode(parsedStr);
          } catch (e) {
            debugPrint("❌ JSON decode failed for $id: $e");
            continue;
          }

          if (parsedJson is! Map<String, dynamic>) continue;

          await roleSync.syncRoleFromParsedData(parsedJson);

          if (currentEpoch > maxEpochSeen) {
            maxEpochSeen = currentEpoch;
          }
        } catch (e, st) {
          debugPrint("❌ Error processing ${m.id}: $e\n$st");
        }
      }

      if (maxEpochSeen > lastEpoch) {
        await ProcessedEmailStore.setLastProcessedEpochSec(maxEpochSeen + 1);
        debugPrint("🔄 Updated lastEpoch → ${maxEpochSeen + 1}");
      }

      debugPrint("✅ Background worker finished.");
      return Future.value(true);
    } catch (e, st) {
      debugPrint("❌ Background fatal error: $e\n$st");
      return Future.value(true);
    }
  });
}

int _internalMillis(gmail.Message? m) {
  if (m?.internalDate == null) return 0;
  return int.tryParse(m!.internalDate!) ?? 0;
}
