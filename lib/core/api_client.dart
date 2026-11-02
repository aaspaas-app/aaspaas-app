// Small HTTP client for the Aas Paas REST API. Uses only dart:io, so it needs no extra packages.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    required this.status,
  });

  /// Machine-readable reason, for example "unverified", "invalid", "network".
  final String code;

  /// Text that is safe to show to the person.
  final String message;

  /// HTTP status, or 0 when the request never reached the server (no internet, timeout).
  final int status;

  bool get isNetwork => status == 0;
  bool get isAuth => status == 401;
  bool get isNotFound => status == 404;

  @override
  String toString() => 'ApiException($code, $status): $message';
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 15),
    this.userAgent = 'AasPaasApp/1.0',
    HttpClient? client,
  }) : _http = client ?? HttpClient();

  /// For example https://example.com/wp-json/aaspaas/v1 (no trailing slash).
  final String baseUrl;
  final Duration timeout;
  final String userAgent;
  final HttpClient _http;

  /// Set after login. Sent as X-AP-Token on every request.
  String? token;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body ?? <String, dynamic>{});

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) =>
      _send('DELETE', path, body: body);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    try {
      final req = await _http.openUrl(method, uri).timeout(timeout);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      req.headers.set(HttpHeaders.userAgentHeader, userAgent);
      final t = token;
      if (t != null && t.isNotEmpty) {
        req.headers.set('X-AP-Token', t);
      }
      if (body != null) {
        req.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json; charset=utf-8',
        );
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      return _decode(res.statusCode, text);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        code: 'network',
        message: 'The server took too long to answer. Please try again.',
        status: 0,
      );
    } on SocketException {
      throw ApiException(
        code: 'network',
        message: 'No internet connection.',
        status: 0,
      );
    } on HandshakeException {
      throw ApiException(
        code: 'network',
        message: 'A secure connection could not be made.',
        status: 0,
      );
    } on HttpException {
      throw ApiException(
        code: 'network',
        message: 'Could not reach the server.',
        status: 0,
      );
    }
  }

  dynamic _decode(int status, String text) {
    dynamic data;
    if (text.trim().isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        // Not JSON: a host error page, or a security plugin answering instead of the API.
        throw ApiException(
          code: 'bad_response',
          message: 'The server sent an unexpected answer (HTTP $status).',
          status: status == 200 ? 502 : status,
        );
      }
    }
    if (status >= 200 && status < 300) {
      return data;
    }
    String code = 'error';
    String message = 'Something went wrong (HTTP $status).';
    if (data is Map) {
      if (data['code'] != null) code = data['code'].toString();
      if (data['message'] != null && data['message'].toString().isNotEmpty)
        message = data['message'].toString();
    }
    throw ApiException(code: code, message: message, status: status);
  }

  void close() => _http.close(force: true);
}
