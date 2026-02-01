import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:workmanager/workmanager.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import 'gmail_service.dart';
import 'gemini_parser.dart';
import 'role_sync_service.dart';
import '../utils/processed_email_store.dart';
import '../utils/applogger.dart';
import '../utils/email_retry_store.dart';

class BackgroundService {
  static const String _taskUniqueName = "placement_email_worker";
  static const String _taskImmediate = "placement_email_worker_now";

  /// Initialize WorkManager callback dispatcher. Must be called once in main().
  static Future<void> initialize() async {
    Workmanager().initialize(
      callbackDispatcher, // <- top-level function
    );

    AppLogger.log("⚙ Workmanager initialized.");
  }

  /// Start periodic task
  static Future<void> start() async {
    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskUniqueName,
      frequency: const Duration(minutes: 55),
      initialDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );

    await ProcessedEmailStore.setBackgroundRunning(true);
    AppLogger.log("🔁 Background periodic task scheduled.");
  }

  /// Trigger one-off task immediately
  static Future<void> triggerNow() async {
    await Workmanager().registerOneOffTask(
      _taskImmediate,
      _taskImmediate,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
    AppLogger.log("🚀 Immediate background task triggered.");
  }

  /// Stop periodic task
  static Future<void> stop() async {
    await Workmanager().cancelByUniqueName(_taskUniqueName);
    await ProcessedEmailStore.setBackgroundRunning(false);
    AppLogger.log("🛑 Background job cancelled.");
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
      AppLogger.log("⏳ Rate limit hit — waiting $wait sec");
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
      AppLogger.log("📬 Background job started: $task");

      final gmailService = GmailService();
      final rateLimiter = GeminiRateLimiter(maxRequestsPerMinute: 5);
      const maxRetries = 3;

      final parser = await GeminiParser.createFromPrefs();
      if (parser == null) {
        await AppLogger.log("❌ GeminiParser missing API key. Skipping.");
        await AppLogger.flush();
        return Future.value(false);
      }

      final roleSync = RoleSyncService();

      final signedIn = await gmailService.signIn();
      if (!signedIn) {
        await AppLogger.log("❌ Gmail background sign-in failed.");
        await AppLogger.flush();
        return Future.value(false);
      }

      // sliding window
      int lastEpoch = await ProcessedEmailStore.getLastProcessedEpochSec();
      if (lastEpoch == 0) {
        lastEpoch =
            DateTime.now()
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch ~/
            1000;
        AppLogger.log("🕒 First run → fetching last 2 days.");
      }

      const baseQuery = '''
      from:channeli.img@iitr.ac.in
      "open in noticeboard"
      -subject:"shortlist for interviews"
      ''';

      List<gmail.Message> msgs = [];

      try {
        msgs = await gmailService.fetchMessagesSince(
          baseQuery: baseQuery,
          afterEpochSeconds: lastEpoch,
          pageSize: 50,
        );
      } catch (e) {
        await AppLogger.log("⚠ fetchMessagesSince failed: $e");
        await AppLogger.flush();
        return Future.value(false);
      }

      if (msgs.isEmpty) {
        await AppLogger.log("📭 No new messages found.");
        await AppLogger.flush();
        return Future.value(true);
      }

      // Gmail returns newest → oldest
      msgs = msgs.reversed.toList();
      AppLogger.log("🔄 Processing ${msgs.length} messages (Oldest → Newest)");

      for (var m in msgs) {
        if (m.id == null) continue;
        final id = m.id!;
        try {
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
          if (body == null || body.trim().isEmpty) {
            AppLogger.log("❌ Empty email body. Skipping this email.");
            //in this case epoch is not updated.
            continue;
          }

          AppLogger.log(
            "📧 [${DateTime.fromMillisecondsSinceEpoch(currentEpoch * 1000)}] $subject\n $body",
          );

          final parsedStr = await parser.parseEmail(
            subject: subject,
            body: body,
            emailReceivedDateTime: dateHeader,
          );

          AppLogger.log(parsedStr);

          dynamic parsedJson;
          try {
            parsedJson = jsonDecode(parsedStr);
          } catch (e) {
            AppLogger.log("❌ JSON decode failed for $id: $e");
            continue;
          }

          if (parsedJson is! Map<String, dynamic>) continue;

          await roleSync.syncRoleFromParsedData(parsedJson);
          AppLogger.log("✅ Roles synced to DB and Calendar successfully.");

          //checkpoint
          if (currentEpoch > lastEpoch) {
            lastEpoch = currentEpoch;
            await ProcessedEmailStore.setLastProcessedEpochSec(lastEpoch);
          }
          // success → cleanup retry state
          await EmailRetryStore.clear(id);
        } catch (e, st) {
          AppLogger.log("❌ Error processing ${m.id}: $e\n$st");

          final retryCount = await EmailRetryStore.getRetryCount(id);
          if (retryCount >= maxRetries) {
            AppLogger.log(
              "🚫 Max retries reached for $id. Skipping permanently.",
            );
            continue; // skip permanently
          }

          // retry later
          await EmailRetryStore.incrementRetry(id);

          await AppLogger.log("⚠️ Retry this email.");
          await AppLogger.flush();
          return Future.value(false);
        }
      }

      await AppLogger.log("✅ Background worker finished.");
      await AppLogger.flush();
      await EmailRetryStore.clearAll();
      return Future.value(true);
    } catch (e, st) {
      await AppLogger.log("❌ Background fatal error: $e\n$st");
      await AppLogger.flush();
      return Future.value(false);
    }
  });
}

int _internalMillis(gmail.Message? m) {
  if (m?.internalDate == null) return 0;
  return int.tryParse(m!.internalDate!) ?? 0;
}
