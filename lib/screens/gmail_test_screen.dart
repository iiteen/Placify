import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../services/gmail_service.dart';
import '../services/gemini_parser.dart';

class GmailTestScreen extends StatefulWidget {
  const GmailTestScreen({super.key});
  @override
  State<GmailTestScreen> createState() => _GmailTestScreenState();
}

class _GmailTestScreenState extends State<GmailTestScreen> {
  final GmailService _gmail = GmailService();
  List<gmail.Message> _messages = [];
  bool _signedIn = false;
  bool _loading = false;

  Future<void> _signIn() async {
    final ok = await _gmail.signIn();
    setState(() => _signedIn = ok);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    // Example query:
    // from:channeli@example.com subject:(PPT OR Test OR Interview) is:unread
    final query = '''
from:channeli.img@iitr.ac.in
subject:(
"Submission Of Biodata"
OR "Submission of Bio data"
)
        ''';
    final metas = await _gmail.searchAndFetchMetadata(
      query: query,
      maxResults: 50,
    );
    setState(() {
      _messages = metas;
      _loading = false;
    });
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
        final body = await _gmail.getFullMessageBody(m.id!);
        final subject =
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

        // Ask user to store Gemini key somewhere else (constants / secure storage).
        const geminiApiKey = "YOUR_GEMINI_API_KEY";

        final parser = GeminiParser(geminiApiKey);

        final jsonResult = await parser.parseEmail(
          subject: subject,
          body: body ?? "",
        );

        debugPrint("=============== PARSED JSON ================");
        debugPrint(jsonResult);
        debugPrint("============================================");

        // OPTIONALLY SHOW POPUP
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text("Parsed Data"),
            content: SingleChildScrollView(child: Text(jsonResult)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
            ],
          ),
        );
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
          if (_loading) const CircularProgressIndicator(),
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
