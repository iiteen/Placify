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
      // Attempt to sign in. In background tasks this must be a silent sign-in
      // or previously granted credentials must be present.
      _account = await _googleSignIn.signInSilently();
      _account ??= await _googleSignIn.signIn();

      if (_account == null) return false;

      final headers = await _account!.authHeaders;
      final client = GoogleHttpClient(headers);
      _api = gmail.GmailApi(client);
      debugPrint('✅ Signed in as: ${_account!.email}');
      return true;
    } catch (e, st) {
      debugPrint("❌ Gmail signIn error: $e\n$st");
      _api = null;
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

  /// Lightweight list of message ids matching a query (single page).
  /// Keep for compatibility with existing code.
  Future<List<gmail.Message>?> listMessageIds({
    required String query,
    int maxResults = 100,
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

  /// Fetch ALL messages (ids + threadId etc) that match the query and are
  /// newer than the given epoch-second timestamp. This method paginates
  /// through all pages using pageToken, so it will return *all* matching messages.
  ///
  /// Uses Gmail 'after:' operator with epoch seconds.
  Future<List<gmail.Message>> fetchMessagesSince({
    required String
    baseQuery, // e.g. 'from:channeli.img@iitr.ac.in subject:(...)'
    required int afterEpochSeconds,
    int pageSize = 100, // page size; Gmail allows up to 500 but 100 is safe
  }) async {
    try {
      if (_api == null) {
        debugPrint('Gmail API not initialized. Call signIn() first.');
        return [];
      }

      // Build query with 'after' (epoch seconds)
      final query = '$baseQuery after:$afterEpochSeconds';
      List<gmail.Message> results = [];
      String? pageToken;
      do {
        final resp = await _api!.users.messages.list(
          'me',
          q: query,
          maxResults: pageSize,
          pageToken: pageToken,
        );

        if (resp.messages != null && resp.messages!.isNotEmpty) {
          results.addAll(resp.messages!);
        }

        pageToken = resp.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);

      return results;
    } catch (e, st) {
      debugPrint("❌ Gmail fetchMessagesSince error: $e\n$st");
      return [];
    }
  }

  /// Fetch metadata-only for a single message (headers only)
  Future<gmail.Message?> getMessageMetadata(String messageId) async {
    try {
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
    } catch (e, st) {
      debugPrint("❌ Gmail getMessageMetadata error: $e\n$st");
      return null;
    }
  }

  /// Convenience: search + fetch metadata for each hit (single-page variant)
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

  /// Fetch FULL message including body, attachments, HTML, etc.
  Future<String?> getFullMessageBody(String messageId) async {
    try {
      if (_api == null) {
        debugPrint('Gmail API not initialized. Call signIn() first.');
        return null;
      }

      final msg = await _api!.users.messages.get(
        'me',
        messageId,
        format: 'full',
      );

      if (msg.payload == null) return null;

      // Decode raw HTML or text
      final raw = _extractBody(msg.payload!);
      if (raw == null || raw.trim().isEmpty) return null;

      // Extract ONLY mail-body content using HTML parser
      return _extractCleanMailBody(raw);
    } catch (e, st) {
      debugPrint("❌ Gmail getFullMessageBody error: $e\n$st");
      return null;
    }
  }

  /// Recursively extract *raw* HTML/text from Gmail parts
  String? _extractBody(gmail.MessagePart part) {
    try {
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
    } catch (e, st) {
      debugPrint("❌ _extractBody error: $e\n$st");
      return null;
    }
  }

  /// Decode Gmail’s URL-safe Base64
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

  /// Extract ONLY content inside <div class="mail-body"> and clean it
  String _extractCleanMailBody(String html) {
    try {
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
    } catch (e, st) {
      debugPrint("❌ _extractCleanMailBody error: $e\n$st");
      return html;
    }
  }
}
