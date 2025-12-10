// gmail_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
// import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // debugPrint

import '../utils/google_http_client.dart';

class GmailService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      gmail.GmailApi.gmailReadonlyScope,
      // use gmailModifyScope if you plan to mark messages read/modify labels later
      // gmail.GmailApi.gmailModifyScope,
    ],
  );

  GoogleSignInAccount? _account;
  gmail.GmailApi? _api;

  Future<bool> signIn() async {
    _account = await _googleSignIn.signIn();
    if (_account == null) return false;

    final headers = await _account!.authHeaders;
    final client = GoogleHttpClient(headers);
    _api = gmail.GmailApi(client);
    debugPrint('✅ Signed in as: ${_account!.email}');
    return true;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    _api = null;
  }

  /// List messages matching a query (just id + threadId) - light weight
  Future<List<gmail.Message>?> listMessageIds({
    required String query,
    int maxResults = 20,
  }) async {
    if (_api == null) {
      debugPrint('Gmail API not initialized. Call signIn() first.');
      return null;
    }

    final resp = await _api!.users.messages.list(
      'me',
      q: query,
      maxResults: maxResults,
    );

    return resp.messages;
  }

  /// Fetch metadata-only for a single message (headers only)
  Future<gmail.Message?> getMessageMetadata(String messageId) async {
    if (_api == null) {
      debugPrint('Gmail API not initialized. Call signIn() first.');
      return null;
    }
    final msg = await _api!.users.messages.get(
      'me',
      messageId,
      format: 'metadata',
      metadataHeaders: ['From', 'Subject', 'Date'],
    );
    return msg;
  }

  /// Convenience: search + fetch metadata for each hit
  Future<List<gmail.Message>> searchAndFetchMetadata({
    required String query,
    int maxResults = 20,
  }) async {
    final ids = await listMessageIds(query: query, maxResults: maxResults);
    if (ids == null || ids.isEmpty) return [];

    final List<gmail.Message> results = [];
    for (var m in ids) {
      if (m.id == null) continue;
      final meta = await getMessageMetadata(m.id!);
      if (meta != null) results.add(meta);
    }
    return results;
  }
}
