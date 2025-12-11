import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../services/gmail_service.dart';
import '../services/gemini_parser.dart';
import '../services/role_sync_service.dart';
import '../utils/processed_email_store.dart';

class BackgroundService {
  static const String taskName = "hourly_email_job";

  /// Call this once in main()
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  /// Call this once when user enables email scanning
  static Future<void> registerHourlyJob() async {
    await Workmanager().registerPeriodicTask(
      "email-worker",
      taskName,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

/// THIS EXECUTES IN A BACKGROUND ISOLATE
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("📬 Background email scan started...");

      final gmail = GmailService();
      final roleSync = RoleSyncService();
      //TODO: centralise this
      const geminiApiKey = "YOUR_GEMINI_API_KEY";
      final parser = GeminiParser(geminiApiKey);

      // ————————————————————————————————
      // 1. Google sign-in (silent)
      // ————————————————————————————————
      final signedIn = await gmail.signIn();
      if (!signedIn) {
        debugPrint("❌ Background Gmail sign-in failed.");
        return Future.value(true);
      }

      // ————————————————————————————————
      // 2. Determine timestamp of last processed email
      // ————————————————————————————————
      int lastEpoch = await ProcessedEmailStore.getLastProcessedEpochSec();

      if (lastEpoch == 0) {
        // FIRST RUN → fetch only last 7 days
        lastEpoch =
            DateTime.now()
                .subtract(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000;

        debugPrint("📌 First run → fetching last 7 days (epoch $lastEpoch)");
      } else {
        debugPrint("📌 Fetching new emails after epoch: $lastEpoch");
      }

      // ————————————————————————————————
      // 3. Build Gmail query
      // ————————————————————————————————
      final query =
          'from:channeli.img@iitr.ac.in '
          'subject:("Submission Of Biodata" OR "Submission of Bio data") '
          'after:$lastEpoch';

      // ————————————————————————————————
      // 4. Fetch metadata for new emails
      // ————————————————————————————————
      final metas = await gmail.searchAndFetchMetadata(
        query: query,
        maxResults: 20,
      );

      if (metas.isEmpty) {
        debugPrint("📭 No new mails.");
        return Future.value(true);
      }

      // ————————————————————————————————
      // 5. Process each email
      // ————————————————————————————————
      for (final meta in metas) {
        try {
          if (meta.id == null) continue;

          // Extract essential headers
          String subject = "(no subject)";
          String receivedDate = "";

          for (var h in meta.payload?.headers ?? []) {
            if (h.name?.toLowerCase() == "subject") {
              subject = h.value ?? "(no subject)";
            }
            if (h.name?.toLowerCase() == "date") {
              receivedDate = h.value ?? "";
            }
          }

          // Fetch full message body
          final body = await gmail.getFullMessageBody(meta.id!);
          if (body == null || body.isEmpty) continue;

          // Parse using Gemini
          final parsedStr = await parser.parseEmail(
            subject: subject,
            body: body,
            emailReceivedDateTime: receivedDate,
          );

          Map<String, dynamic>? parsedJson;
          try {
            final decoded = jsonDecode(parsedStr);
            if (decoded is Map<String, dynamic>) {
              parsedJson = decoded;
            } else {
              debugPrint("❌ Gemini JSON is not a map → skipping.");
              continue;
            }
          } catch (_) {
            debugPrint("❌ Gemini JSON invalid → skipping.");
            continue;
          }

          // Sync to DB and Calendar
          await roleSync.syncRoleFromParsedData(parsedJson);
          debugPrint("✅ Email processed successfully.");


          // Update last processed timestamp
          final receivedEpoch =
              DateTime.tryParse(receivedDate)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch;

          await ProcessedEmailStore.saveLastProcessedEpochSec(
            receivedEpoch ~/ 1000,
          );
        } catch (e, st) {
          debugPrint("❌ Error processing one email: $e\n$st");
        }
      }

      debugPrint("🎉 Background job completed.");
      return Future.value(true);
    } catch (e, st) {
      debugPrint("❌ Fatal background error: $e\n$st");
      return Future.value(true);
    }
  });
}
