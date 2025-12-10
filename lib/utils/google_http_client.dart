import 'dart:async';
import 'package:http/http.dart' as http;

/// A small wrapper that injects the OAuth headers into every request.
/// We build it using headers from google_sign_in.currentUser!.authHeaders
class GoogleHttpClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  GoogleHttpClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
