import 'dart:convert';
import 'package:http/http.dart' as origin_http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Re-export everything from package:http except the elements we are customizing
export 'package:http/http.dart' hide get, post, put, delete, MultipartRequest;

// Same keys as ApiService / NetworkService (kept here to avoid an import cycle).
const String _sessionPrefsKey = 'cached_user_session';
const String _devBaseUrlKey = 'dev_base_url_override';

bool _isExternal(Uri url) => url.host.contains('google') || url.host.contains('googleapis');

/// True when [url] goes to our own Odoo server: the staff URL override if set,
/// else API_BASE_URL from .env. The session is never sent anywhere else.
bool _isOwnServer(Uri url, SharedPreferences prefs) {
  final override = (prefs.getString(_devBaseUrlKey) ?? '').trim();
  final base = Uri.tryParse(override.isNotEmpty ? override : (dotenv.env['API_BASE_URL'] ?? ''));
  return base != null && base.host.isNotEmpty && base.host == url.host && base.port == url.port;
}

/// Adds X-API-Key (as before) and, for our own server, the login session as
/// X-Openerp-Session-Id, so the server can check who is calling on every route.
/// Headers the caller already set (e.g. ApiService._authHeaders) are kept as they are.
Future<Map<String, String>> _injectHeaders(Uri url, Map<String, String>? headers) async {
  final Map<String, String> finalHeaders = headers != null ? Map<String, String>.from(headers) : {};

  // Do not send local API key or session to external google maps/places APIs
  if (_isExternal(url)) {
    return finalHeaders;
  }

  final apiKey = dotenv.env['API_KEY'];
  if (apiKey != null && apiKey.isNotEmpty) {
    finalHeaders['X-API-Key'] = apiKey;
  }

  if (!finalHeaders.containsKey('X-Openerp-Session-Id')) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sid = (prefs.getString(_sessionPrefsKey) ?? '').trim();
      if (sid.isNotEmpty && _isOwnServer(url, prefs)) {
        finalHeaders['X-Openerp-Session-Id'] = sid;
      }
    } catch (_) {
      // No prefs (tests, very early start): send without a session, as before.
    }
  }
  return finalHeaders;
}

/// Overridden get request that injects the API Key and session
Future<origin_http.Response> get(Uri url, {Map<String, String>? headers}) async {
  final finalHeaders = await _injectHeaders(url, headers);
  return origin_http.get(url, headers: finalHeaders);
}

/// Overridden post request that injects the API Key and session
Future<origin_http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final finalHeaders = await _injectHeaders(url, headers);
  return origin_http.post(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Overridden put request that injects the API Key and session
Future<origin_http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final finalHeaders = await _injectHeaders(url, headers);
  return origin_http.put(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Overridden delete request that injects the API Key and session
Future<origin_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final finalHeaders = await _injectHeaders(url, headers);
  return origin_http.delete(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Wrapper class for MultipartRequest to automatically append the X-API-Key and session headers
class MultipartRequest extends origin_http.MultipartRequest {
  MultipartRequest(super.method, super.url);

  @override
  Future<origin_http.StreamedResponse> send() async {
    final injected = await _injectHeaders(url, headers);
    headers.addAll(injected);
    return super.send();
  }
}
