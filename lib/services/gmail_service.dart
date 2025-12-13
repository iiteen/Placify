import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

import '../utils/google_http_client.dart';
import '../utils/applogger.dart';

class GmailService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[gmail.GmailApi.gmailReadonlyScope],
  );

  GoogleSignInAccount? _account;
  gmail.GmailApi? _api;

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signInSilently();
      _account ??= await _googleSignIn.signIn();

      if (_account == null) return false;

      final headers = await _account!.authHeaders;
      final client = GoogleHttpClient(headers);
      _api = gmail.GmailApi(client);
      AppLogger.log('✅ Signed in as: ${_account!.email}');
      return true;
    } catch (e, st) {
      AppLogger.log("❌ Gmail signIn error: $e\n$st");
      _api = null;
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      AppLogger.log("❌ Gmail signOut error: $e\n$st");
    }
    _account = null;
    _api = null;
  }

  /// Fetch ALL messages (ids + threadId only) matching query + time.
  /// Returns Newest -> Oldest (API default).
  Future<List<gmail.Message>> fetchMessagesSince({
    required String baseQuery,
    required int afterEpochSeconds,
    int pageSize = 100,
  }) async {
    try {
      if (_api == null) {
        AppLogger.log('Gmail API not initialized.');
        return [];
      }

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
      AppLogger.log("❌ Gmail fetchMessagesSince error: $e\n$st");
      return [];
    }
  }

  /// Fetch metadata + InternalDate for a single message
  Future<gmail.Message?> getMessageMetadata(String messageId) async {
    try {
      if (_api == null) return null;

      // format: 'metadata' automatically includes internalDate (top-level)
      // and payload.headers.
      final msg = await _api!.users.messages.get(
        'me',
        messageId,
        format: 'metadata',
        metadataHeaders: ['From', 'Subject', 'Date'],
      );
      return msg;
    } catch (e, st) {
      AppLogger.log("❌ Gmail getMessageMetadata error: $e\n$st");
      return null;
    }
  }

  /// Convenience: search + fetch metadata (single-page variant)
  Future<List<gmail.Message>> searchAndFetchMetadata({
    required String query,
    int maxResults = 20,
  }) async {
    try {
      if (_api == null) return [];

      // 1. Get IDs
      final resp = await _api!.users.messages.list(
        'me',
        q: query,
        maxResults: maxResults,
      );

      final ids = resp.messages ?? [];
      if (ids.isEmpty) return [];

      // 2. Fetch details for each
      final List<gmail.Message> results = [];
      for (var m in ids) {
        if (m.id == null) continue;
        final meta = await getMessageMetadata(m.id!);
        if (meta != null) results.add(meta);
      }
      return results;
    } catch (e, st) {
      AppLogger.log("❌ Gmail searchAndFetchMetadata error: $e\n$st");
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
      AppLogger.log("❌ Gmail getFullMessageBody error: $e\n$st");
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
    } catch (e) {
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
    } catch (e) {
      return '';
    }
  }

  String _extractCleanMailBody(String html) {
    try {
      final document = html_parser.parse(html);
      final bodyDiv = document.querySelector('.mail-body');
      String cleanedText = (bodyDiv != null)
          ? bodyDiv.text
          : (document.body?.text ?? html);
      return cleanedText.trim();
    } catch (e) {
      return html;
    }
  }
}
