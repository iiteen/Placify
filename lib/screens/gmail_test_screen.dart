import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../services/gmail_service.dart';
import '../services/gemini_parser.dart';
import '../services/role_sync_service.dart';
import '../utils/applogger.dart';

class GmailTestScreen extends StatefulWidget {
  const GmailTestScreen({super.key});
  @override
  State<GmailTestScreen> createState() => _GmailTestScreenState();
}

class _GmailTestScreenState extends State<GmailTestScreen> {
  final GmailService _gmail = GmailService();
  final RoleSyncService _roleSync = RoleSyncService();

  List<gmail.Message> _messages = [];
  bool _signedIn = false;
  bool _loading = false;

  Future<void> _signIn() async {
    try {
      final ok = await _gmail.signIn();
      if (!mounted) return;
      setState(() => _signedIn = ok);
    } catch (e, st) {
      AppLogger.log("❌ Gmail sign-in failed: $e\n$st");
    }
  }

  Future<void> _search() async {
    try {
      if (!mounted) return;
      setState(() => _loading = true);

      //       final query = '''
      // from:channeli.img@iitr.ac.in
      // subject:("Submission Of Biodata" OR "Submission of Bio data")
      //       ''';
      final query = '''
      from:channeli.img@iitr.ac.in
      "open in noticeboard"
      "Isgec Heavy Engineering Ltd"
      ''';

      final metas = await _gmail.searchAndFetchMetadata(
        query: query,
        maxResults: 100,
      );

      if (!mounted) return;
      setState(() {
        _messages = metas;
        _loading = false;
      });
    } catch (e, st) {
      AppLogger.log("❌ Gmail search failed: $e\n$st");
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildMessageTile(gmail.Message m) {
    String from = '';
    String subject = '';
    String date = '';

    if (m.payload?.headers != null) {
      for (var h in m.payload!.headers!) {
        if (h.name?.toLowerCase() == 'from') from = h.value ?? '';
        if (h.name?.toLowerCase() == 'subject') subject = h.value ?? '';
        if (h.name?.toLowerCase() == 'date') date = h.value ?? '';
      }
    }

    return ListTile(
      title: Text(subject.isNotEmpty ? subject : '(no subject)'),
      subtitle: Text('From: $from\nDate: $date'),
      isThreeLine: true,
      onTap: () async {
        if (!mounted) return;
        setState(() => _loading = true);

        try {
          final body = await _gmail.getFullMessageBody(m.id!);
          final subjectHeader =
              m.payload?.headers
                  ?.firstWhere(
                    (h) => h.name?.toLowerCase() == "subject",
                    orElse: () => gmail.MessagePartHeader(),
                  )
                  .value ??
              "(no subject)";

          AppLogger.log("================ EMAIL SUBJECT ================");
          AppLogger.log(subjectHeader);
          AppLogger.log("================ RAW EMAIL BODY ================");
          AppLogger.log(body ?? "NO BODY FOUND");
          AppLogger.log("================================================");

          // Skip further processing if body is empty
          if (body == null || body.trim().isEmpty) {
            AppLogger.log("❌ Empty email body. Skipping this email.");
            setState(() => _loading = false); // Stop loading
            return;
          }

          final parser = await GeminiParser.createFromPrefs();
          if (parser == null) {
            AppLogger.log("❌ Gemini API key not set in settings.");
            setState(() => _loading = false); // Stop loading
            return;
          }

          final parsedJsonStr = await parser.parseEmail(
            subject: subjectHeader,
            body: body,
            emailReceivedDateTime: date,
          );

          AppLogger.log("=============== PARSED JSON ================");
          AppLogger.log(parsedJsonStr);
          AppLogger.log("============================================");

          Map<String, dynamic>? parsedData;
          try {
            parsedData = jsonDecode(parsedJsonStr) as Map<String, dynamic>;
          } catch (e) {
            AppLogger.log("❌ Failed to parse Gemini JSON: $e");
          }

          if (parsedData != null) {
            try {
              await _roleSync.syncRoleFromParsedData(parsedData);
              AppLogger.log("✅ Roles synced to DB and Calendar successfully.");
            } catch (e, st) {
              AppLogger.log("❌ Error syncing roles: $e\n$st");
            }
          }
        } catch (e, st) {
          AppLogger.log("❌ Error processing email: $e\n$st");
        }

        if (mounted) setState(() => _loading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gmail test')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _signedIn ? null : _signIn,
            child: const Text('Sign in with Google'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _signedIn ? _search : null,
            child: const Text('Search channeli mails (metadata)'),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageTile(_messages[i]),
            ),
          ),
        ],
      ),
    );
  }
}
