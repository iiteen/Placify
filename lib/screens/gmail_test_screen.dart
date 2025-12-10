import 'package:flutter/material.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

import '../services/gmail_service.dart';

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
    final query ='''
from:channeli.img@iitr.ac.in
subject:(
"Submission Of Biodata"
OR "Submission of Bio data"
)
        ''';
    final metas = await _gmail.searchAndFetchMetadata(
      query: query,
      maxResults: 20,
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
