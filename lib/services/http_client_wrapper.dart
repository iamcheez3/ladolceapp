import 'dart:convert';
import 'package:http/http.dart' as origin_http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Re-export everything from package:http except the elements we are customizing
export 'package:http/http.dart' hide get, post, put, delete, MultipartRequest;

/// Helper function to inject X-API-Key header if configured in environment
/// and target is our own backend (not external like google APIs)
Map<String, String> _injectApiKey(Uri url, Map<String, String>? headers) {
  final Map<String, String> finalHeaders = headers != null ? Map<String, String>.from(headers) : {};
  
  // Do not send local API key to external google maps/places APIs
  if (url.host.contains('google') || url.host.contains('googleapis')) {
    return finalHeaders;
  }

  final apiKey = dotenv.env['API_KEY'];
  if (apiKey != null && apiKey.isNotEmpty) {
    finalHeaders['X-API-Key'] = apiKey;
  }
  return finalHeaders;
}

/// Overridden get request that injects the API Key
Future<origin_http.Response> get(Uri url, {Map<String, String>? headers}) {
  final finalHeaders = _injectApiKey(url, headers);
  return origin_http.get(url, headers: finalHeaders);
}

/// Overridden post request that injects the API Key
Future<origin_http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  final finalHeaders = _injectApiKey(url, headers);
  return origin_http.post(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Overridden put request that injects the API Key
Future<origin_http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  final finalHeaders = _injectApiKey(url, headers);
  return origin_http.put(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Overridden delete request that injects the API Key
Future<origin_http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) {
  final finalHeaders = _injectApiKey(url, headers);
  return origin_http.delete(url, headers: finalHeaders, body: body, encoding: encoding);
}

/// Wrapper class for MultipartRequest to automatically append the X-API-Key header
class MultipartRequest extends origin_http.MultipartRequest {
  MultipartRequest(super.method, super.url);

  @override
  Future<origin_http.StreamedResponse> send() {
    // Only send the API Key if the target is not external Google APIs
    if (!url.host.contains('google') && !url.host.contains('googleapis')) {
      final apiKey = dotenv.env['API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['X-API-Key'] = apiKey;
      }
    }
    return super.send();
  }
}
