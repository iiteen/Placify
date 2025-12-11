import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../utils/google_http_client.dart';

class GmailService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[gmail.GmailApi.gmailReadonlyScope],
  );

  GoogleSignInAccount? _account;
  gmail.GmailApi? _api;

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signIn();
      if (_account == null) return false;

      final headers = await _account!.authHeaders;
      final client = GoogleHttpClient(headers);
      _api = gmail.GmailApi(client);
      debugPrint('✅ Signed in as: ${_account!.email}');
      return true;
    } catch (e, st) {
      debugPrint("❌ Gmail signIn error: $e\n$st");
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      debugPrint("❌ Gmail signOut error: $e\n$st");
    }
    _account = null;
    _api = null;
  }

  Future<List<gmail.Message>?> listMessageIds({
    required String query,
    int maxResults = 20,
  }) async {
    try {
      if (_api == null) {
        debugPrint('Gmail API not initialized. Call signIn() first.');
        return [];
      }

      final resp = await _api!.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      return resp.messages ?? [];
    } catch (e, st) {
      debugPrint("❌ Gmail listMessageIds error: $e\n$st");
      return [];
    }
  }

  Future<gmail.Message?> getMessageMetadata(String messageId) async {
    try {
      if (_api == null) return null;

      final msg = await _api!.users.messages.get(
        'me',
        messageId,
        format: 'metadata',
        metadataHeaders: ['From', 'Subject', 'Date'],
      );
      return msg;
    } catch (e, st) {
      debugPrint("❌ Gmail getMessageMetadata error: $e\n$st");
      return null;
    }
  }

  Future<List<gmail.Message>> searchAndFetchMetadata({
    required String query,
    int maxResults = 20,
  }) async {
    try {
      final ids = await listMessageIds(query: query, maxResults: maxResults);
      if (ids == null || ids.isEmpty) return [];

      final List<gmail.Message> results = [];
      for (var m in ids) {
        if (m.id == null) continue;
        final meta = await getMessageMetadata(m.id!);
        if (meta != null) results.add(meta);
      }
      return results;
    } catch (e, st) {
      debugPrint("❌ Gmail searchAndFetchMetadata error: $e\n$st");
      return [];
    }
  }

  Future<String?> getFullMessageBody(String messageId) async {
    try {
      if (_api == null) return null;

      final msg = await _api!.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );
      if (msg.payload == null) return null;

      final raw = _extractBody(msg.payload!);
      if (raw == null || raw.trim().isEmpty) return null;

      return _extractCleanMailBody(raw);
    } catch (e, st) {
      debugPrint("❌ Gmail getFullMessageBody error: $e\n$st");
      return null;
    }
  }

  String? _extractBody(gmail.MessagePart part) {
    try {
      if (part.body != null && part.body!.data != null) {
        return _decodeBase64(part.body!.data!);
      }

      if (part.parts != null) {
        for (var p in part.parts!) {
          final res = _extractBody(p);
          if (res != null && res.trim().isNotEmpty) return res;
        }
      }

      return null;
    } catch (e, st) {
      debugPrint("❌ _extractBody error: $e\n$st");
      return null;
    }
  }

  String _decodeBase64(String input) {
    try {
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
    } catch (e, st) {
      debugPrint("❌ _decodeBase64 error: $e\n$st");
      return '';
    }
  }

  String _extractCleanMailBody(String html) {
    try {
      final document = html_parser.parse(html);
      final bodyDiv = document.querySelector('.mail-body');

      String cleanedText;
      if (bodyDiv != null) {
        cleanedText = bodyDiv.text;
      } else {
        cleanedText = document.body?.text ?? html;
      }

      return cleanedText.trim();
    } catch (e, st) {
      debugPrint("❌ _extractCleanMailBody error: $e\n$st");
      return html;
    }
  }
}
