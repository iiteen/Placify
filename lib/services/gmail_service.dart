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
  // gmail.GmailApi? _api;

  Future<gmail.GmailApi?> _getApi() async {
    if (_account == null) {
      AppLogger.log('Gmail account not initialized.');
      return null;
    }

    final headers = await _account!.authHeaders; //refresh token
    final client = GoogleHttpClient(headers);
    return gmail.GmailApi(client);
  }

  Future<bool> signIn() async {
    try {
      _account = await _googleSignIn.signInSilently();
      _account ??= await _googleSignIn.signIn();

      if (_account == null) return false;
      AppLogger.log('✅ Signed in as: ${_account!.email}');
      return true;
    } catch (e, st) {
      AppLogger.log("❌ Gmail signIn error: $e\n$st");
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
  }

  /// Fetch ALL messages (ids + threadId only) matching query + time.
  /// Returns Newest -> Oldest (API default).
  Future<List<gmail.Message>> fetchMessagesSince({
    required String baseQuery,
    required int afterEpochSeconds,
    int pageSize = 100,
  }) async {
    try {
      final api = await _getApi();
      if (api == null) {
        AppLogger.log('Gmail API not initialized.');
        return [];
      }

      final query = '$baseQuery after:$afterEpochSeconds';
      List<gmail.Message> results = [];
      String? pageToken;

      do {
        final resp = await api.users.messages.list(
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
      final api = await _getApi();
      if (api == null) return null;

      // format: 'metadata' automatically includes internalDate (top-level)
      // and payload.headers.
      final msg = await api.users.messages.get(
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
      final api = await _getApi();
      if (api == null) {
        AppLogger.log('Gmail API not initialized.');
        return [];
      }

      // 1. Get IDs
      final resp = await api.users.messages.list(
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
      final api = await _getApi();
      if (api == null) return null;

      final msg = await api.users.messages.get('me', messageId, format: 'full');

      if (msg.payload == null) return null;

      final raw = _extractBody(msg.payload!);
      if (raw == null || raw.trim().isEmpty) return null;

      // AppLogger.log("================ HTML Content ================");
      // AppLogger.log(raw);
      // AppLogger.log("================================");

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

  Future<String> _extractCleanMailBody(String html) async {
    final cleanedHtml = await removeEnrollmentTables(html) ?? html;
    try {
      final document = html_parser.parse(cleanedHtml);
      final bodyDiv = document.querySelector('.mail-body');
      if (bodyDiv == null) {
        return document.body?.text.trim() ?? cleanedHtml;
      }

      // Replace <br> and <br /> with newline
      bodyDiv.querySelectorAll('br').forEach((br) {
        br.replaceWith(html_parser.parse('<span>\n</span>').body!.firstChild!);
      });

      return bodyDiv.text.trim();
    } catch (e) {
      return cleanedHtml;
    }
  }

  Future<String?> removeEnrollmentTables(String rawEmailContent) async {
    try {
      // Parse the raw HTML content into a document object model (DOM)
      final document = html_parser.parse(rawEmailContent);

      // Find all the tables in the document
      final tables = document.getElementsByTagName('table');

      // Loop through each table and check if it contains "enrollment"
      for (var table in tables) {
        // Find all headers (either <th> or <td>) in the table
        final headers =
            table.getElementsByTagName('th') + table.getElementsByTagName('td');

        // Check if any of the headers contain the word "enrollment" (case insensitive)
        bool containsEnrollment = false;
        for (var header in headers) {
          final headerText = header.text.toLowerCase();

          if (headerText.contains('enrollment') ||
              headerText.contains('enrolment')) {
            containsEnrollment = true;
            break; // Stop as soon as we find "enrollment"
          }
        }

        // If the table contains "enrollment", remove it from the document
        if (containsEnrollment) {
          table.remove();
        }
      }

      // Return the modified HTML without the unwanted tables
      return document.outerHtml; // Convert the modified DOM back to HTML
    } catch (e) {
      AppLogger.log("❌ Error while removing enrollment tables: $e");
      return rawEmailContent;
    }
  }
}
