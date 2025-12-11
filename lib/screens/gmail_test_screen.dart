import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import '../services/gmail_service.dart';
import '../services/gemini_parser.dart';
import '../services/role_sync_service.dart';

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
      debugPrint("❌ Gmail sign-in failed: $e\n$st");
    }
  }

  Future<void> _search() async {
    try {
      if (!mounted) return;
      setState(() => _loading = true);

      final query = '''
from:channeli.img@iitr.ac.in
subject:("Submission Of Biodata" OR "Submission of Bio data")
      ''';

      final metas = await _gmail.searchAndFetchMetadata(
        query: query,
        maxResults: 5,
      );

      if (!mounted) return;
      setState(() {
        _messages = metas;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint("❌ Gmail search failed: $e\n$st");
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

          debugPrint("================ RAW EMAIL BODY ================");
          debugPrint(body ?? "NO BODY FOUND");
          debugPrint("================================================");

          const geminiApiKey = "YOUR_GEMINI_API_KEY";
          final parser = GeminiParser(geminiApiKey);

          final parsedJsonStr = await parser.parseEmail(
            subject: subjectHeader,
            body: body ?? "",
          );

          debugPrint("=============== PARSED JSON ================");
          debugPrint(parsedJsonStr);
          debugPrint("============================================");

          Map<String, dynamic>? parsedData;
          try {
            parsedData = jsonDecode(parsedJsonStr) as Map<String, dynamic>;
          } catch (e) {
            debugPrint("❌ Failed to parse Gemini JSON: $e");
          }

          if (parsedData != null) {
            try {
              await _roleSync.syncRoleFromParsedData(parsedData);
              debugPrint("✅ Roles synced to DB and Calendar successfully.");
            } catch (e, st) {
              debugPrint("❌ Error syncing roles: $e\n$st");
            }
          }
        } catch (e, st) {
          debugPrint("❌ Error processing email: $e\n$st");
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
