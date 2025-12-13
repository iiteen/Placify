import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import 'gmail_service.dart';
import 'gemini_parser.dart';
import 'role_sync_service.dart';
import '../utils/processed_email_store.dart';

/// Call this from UI to test logic without Workmanager
Future<void> runEmailProcessingOnceForDebug() async {
  debugPrint("🧪 DEBUG email processor started");

  final gmailService = GmailService();
  final rateLimiter = GeminiRateLimiter(maxRequestsPerMinute: 5);

  // Load Gemini parser
  final parser = await GeminiParser.createFromPrefs();
  if (parser == null) {
    debugPrint("❌ Gemini API key missing");
    return;
  }

  final roleSync = RoleSyncService();

  // Gmail login
  final signedIn = await gmailService.signIn();
  if (!signedIn) {
    debugPrint("❌ Gmail sign-in failed");
    return;
  }

  // Sliding window
  int lastEpoch = await ProcessedEmailStore.getLastProcessedEpochSec();
  if (lastEpoch == 0) {
    // Default to 1 day ago if no history
    lastEpoch =
        DateTime.now()
            .subtract(const Duration(days: 2))
            .millisecondsSinceEpoch ~/
        1000;
    debugPrint("🕒 First run → fetching last 2 day");
  }

  final baseQuery =
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
    // Fallback usually not needed if fetchMessagesSince is robust, but kept for safety
    msgs = await gmailService.searchAndFetchMetadata(
      query: '$baseQuery after:$lastEpoch',
      maxResults: 20,
    );
  }

  if (msgs.isEmpty) {
    debugPrint("📭 No new messages found");
    return;
  }

  debugPrint("📥 Fetched ${msgs.length} raw IDs (Newest First by default)");

  // --- CRITICAL FIX: Reverse the list to process Oldest -> Newest ---
  // The API returns Newest First. The list items do NOT have internalDate populated yet,
  // so we cannot sort by property. We must rely on the API's implicit order and reverse it.
  msgs = msgs.reversed.toList();

  debugPrint("🔄 Reversed list to process Oldest First");

  int maxEpochSeen = lastEpoch;

  for (final m in msgs) {
    try {
      final id = m.id;
      if (id == null) continue;

      // Acquire rate limit slot before fetching details
      await rateLimiter.acquire();

      // 1. Get Metadata (Headers + InternalDate)
      final meta = await gmailService.getMessageMetadata(id);
      if (meta == null) continue;

      // Extract timestamp correctly from the META object (not the list object 'm')
      final currentMsgEpoch = (_internalMillis(meta) / 1000).floor();

      String subject = "(no subject)";
      String dateHeader = DateTime.now().toIso8601String();

      final headers = meta.payload?.headers ?? const [];
      for (final h in headers) {
        final name = (h.name ?? '').toLowerCase();
        if (name == 'subject') subject = h.value ?? subject;
        if (name == 'date') dateHeader = h.value ?? dateHeader;
      }

      // 2. Get Body
      final body = await gmailService.getFullMessageBody(id);
      if (body == null || body.trim().isEmpty) {
        debugPrint("⚠ Empty body for $id");
        continue;
      }

      debugPrint(
        "📧 [${DateTime.fromMillisecondsSinceEpoch(currentMsgEpoch * 1000)}] Parsing: $subject \n $body",
      );

      final parsedStr = await parser.parseEmail(
        subject: subject,
        body: body,
        emailReceivedDateTime: dateHeader,
      );

      debugPrint("✅ Parsed output:\n$parsedStr");

      final parsedJson = jsonDecode(parsedStr);
      if (parsedJson is! Map<String, dynamic>) {
        debugPrint("⚠ Parsed JSON not a map");
        continue;
      }

      await roleSync.syncRoleFromParsedData(parsedJson);

      // Update maxEpochSeen if this message is newer
      if (currentMsgEpoch > maxEpochSeen) {
        maxEpochSeen = currentMsgEpoch;
      }
    } catch (e, st) {
      debugPrint("❌ Error inside email loop for ID ${m.id}: $e\n$st");
    }
  }

  // Only update storage if we actually moved forward in time
  if (maxEpochSeen > lastEpoch) {
    // Add +1 second to avoid refetching the exact same message next time
    await ProcessedEmailStore.setLastProcessedEpochSec(maxEpochSeen + 1);
    debugPrint("💾 Updated lastEpoch → ${maxEpochSeen + 1}");
  } else {
    debugPrint("⏸ No newer timestamps encountered.");
  }

  debugPrint("✅ DEBUG email processor finished");
}

/// Helpers

/// Safely extract internalDate (Unix millis) from a Message object
int _internalMillis(gmail.Message? m) {
  if (m?.internalDate == null) return 0;
  return int.tryParse(m!.internalDate!) ?? 0;
}

/// Simple rate limiter
class GeminiRateLimiter {
  final int maxRequestsPerMinute;
  final List<DateTime> _calls = [];

  GeminiRateLimiter({required this.maxRequestsPerMinute});

  Future<void> acquire() async {
    final now = DateTime.now();
    // Clear old calls outside the 60s window
    _calls.removeWhere((t) => now.difference(t).inSeconds >= 60);

    if (_calls.length >= maxRequestsPerMinute) {
      final wait = 60 - now.difference(_calls.first).inSeconds + 1;
      if (wait > 0) {
        debugPrint(
          "⏳ Rate limit hit (${_calls.length} calls) → waiting $wait sec",
        );
        await Future.delayed(Duration(seconds: wait));
      }
    }

    _calls.add(DateTime.now());
  }
}
