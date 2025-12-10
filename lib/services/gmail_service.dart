// gmail_service.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
// import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // debugPrint
import 'dart:convert'; // <-- base64
import 'package:html/parser.dart' as html_parser;

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

  /// Fetch FULL message including body, attachments, HTML, etc.
  Future<String?> getFullMessageBody(String messageId) async {
    if (_api == null) {
      debugPrint('Gmail API not initialized. Call signIn() first.');
      return null;
    }

    final msg = await _api!.users.messages.get('me', messageId, format: 'full');

    if (msg.payload == null) return null;

    // Decode raw HTML or text
    final raw = _extractBody(msg.payload!);
    if (raw == null || raw.trim().isEmpty) return null;

    // Extract ONLY mail-body content using HTML parser
    return _extractCleanMailBody(raw);
  }

  /// Recursively extract *raw* HTML/text from Gmail parts
  String? _extractBody(gmail.MessagePart part) {
    // CASE 1: Direct body data (Base64)
    if (part.body != null && part.body!.data != null) {
      return _decodeBase64(part.body!.data!);
    }

    // CASE 2: Look inside nested parts
    if (part.parts != null) {
      for (var p in part.parts!) {
        final res = _extractBody(p);
        if (res != null && res.trim().isNotEmpty) return res;
      }
    }

    return null;
  }

  /// Decode Gmail’s URL-safe Base64
  String _decodeBase64(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');

    switch (normalized.length % 4) {
      case 1:
        normalized += '===';
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
    }

    return String.fromCharCodes(base64.decode(normalized));
  }

  /// Extract ONLY content inside <div class="mail-body"> and clean it
  String _extractCleanMailBody(String html) {
    final document = html_parser.parse(html);

    // Try to find the main content block
    final bodyDiv = document.querySelector('.mail-body');

    String cleanedText;

    if (bodyDiv != null) {
      // extract ONLY mail-body plaintext
      cleanedText = bodyDiv.text;
    } else {
      // fallback: use entire body but still clean
      cleanedText = document.body?.text ?? html;
    }

    cleanedText = cleanedText.trim();

    return cleanedText;
  }
}
