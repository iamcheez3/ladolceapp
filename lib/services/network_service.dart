import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Custom exception for network-related errors
class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final String? endpoint;

  NetworkException(this.message, {this.statusCode, this.endpoint});

  @override
  String toString() =>
      'NetworkException: $message (Status: $statusCode, Endpoint: $endpoint)';
}

/// Secure network service with centralized request handling
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  http.Client? _client;

  /// Keys for SharedPreferences
  static const String _devBaseUrlKey = 'dev_base_url_override';
  static const String _authTokenKey = 'auth_token';

  /// Initialize with optional SSL pinning or custom client
  void initialize({http.Client? customClient}) {
    _client = customClient ?? _createSecureClient();
  }

  /// Create a secure HTTP client with proper timeouts
  http.Client _createSecureClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 30);

    // In production, you might want to add SSL pinning here
    // ioClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    //   // Implement certificate pinning logic
    //   return false;
    // };

    return IOClient(ioClient);
  }

  http.Client get _httpClient {
    _client ??= _createSecureClient();
    return _client!;
  }

  /// Get base URL from .env or SharedPreferences override
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_devBaseUrlKey);

    String baseUrl;
    if (override != null && override.isNotEmpty) {
      baseUrl = override;
    } else {
      // Get from .env file - MUST be configured
      baseUrl = dotenv.env['API_BASE_URL']!;
      if (baseUrl.isEmpty) {
        throw Exception('API_BASE_URL not set in .env file');
      }
    }

    // Convert localhost for Android emulator
    if (Platform.isAndroid && baseUrl.contains('localhost')) {
      baseUrl = baseUrl.replaceAll('localhost', '10.0.2.2');
    }

    return baseUrl;
  }

  /// Get auth token from secure storage
  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_authTokenKey);
  }

  /// Get Odoo session id from SharedPreferences (stored by ApiService on login).
  Future<String?> _getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cached_user_session');
  }

  /// Build request headers with optional auth and content type
  Future<Map<String, String>> _buildHeaders({
    bool requiresAuth = true,
    bool isJson = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (isJson) 'Content-Type': 'application/json',
    };

    final apiKey = dotenv.env['API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      headers['X-API-Key'] = apiKey;
    }

    if (requiresAuth) {
      // Send Odoo session cookie so require_session() can authenticate the request.
      final sessionId = await _getSessionId();
      if (sessionId != null && sessionId.isNotEmpty) {
        headers['Cookie'] = 'session_id=$sessionId;';
        headers['X-Openerp-Session-Id'] = sessionId;
      }
    }

    return headers;
  }

  /// Log request/response (only in debug mode)
  void _logRequest(String method, String url, {Map<String, dynamic>? body}) {
    if (kDebugMode) {
      developer.log('[Network] $method $url', name: 'NetworkService');
      if (body != null) {
        // Sanitize sensitive data before logging
        final sanitizedBody = _sanitizeForLogging(body);
        developer.log('[Network] Body: $sanitizedBody', name: 'NetworkService');
      }
    }
  }

  void _logResponse(String method, String url, int statusCode, {String? body}) {
    if (kDebugMode) {
      developer.log(
        '[Network] $method $url - Status: $statusCode',
        name: 'NetworkService',
      );
      if (body != null) {
        developer.log('[Network] Response: $body', name: 'NetworkService');
      }
    }
  }

  /// Sanitize sensitive data from logs
  Map<String, dynamic> _sanitizeForLogging(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    const sensitiveKeys = ['password', 'token', 'secret', 'key', 'auth'];

    for (final key in sanitized.keys) {
      if (sensitiveKeys.any((s) => key.toLowerCase().contains(s)) &&
          sanitized[key] is String) {
        sanitized[key] = '***REDACTED***';
      }
    }

    return sanitized;
  }

  /// Generic GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      var uri = Uri.parse('$baseUrl$endpoint');

      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      _logRequest('GET', uri.toString());

      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(timeout);

      _logResponse('GET', uri.toString(), response.statusCode,
          body: response.body);

      return _handleResponse(response, endpoint);
    } on SocketException {
      throw NetworkException(
        'No internet connection or server unreachable',
        endpoint: endpoint,
      );
    } on TimeoutException {
      throw NetworkException(
        'Request timeout - server took too long to respond',
        endpoint: endpoint,
      );
    } catch (e) {
      throw NetworkException(
        'GET request failed: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  /// Generic POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    bool throwOnError = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');

      _logRequest('POST', uri.toString(), body: body);

      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      _logResponse('POST', uri.toString(), response.statusCode,
          body: response.body);

      return throwOnError ? _handleResponse(response, endpoint) : response;
    } on SocketException {
      throw NetworkException(
        'No internet connection or server unreachable',
        endpoint: endpoint,
      );
    } on TimeoutException {
      throw NetworkException(
        'Request timeout - server took too long to respond',
        endpoint: endpoint,
      );
    } catch (e) {
      throw NetworkException(
        'POST request failed: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  /// Generic PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');

      _logRequest('PUT', uri.toString(), body: body);

      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      _logResponse('PUT', uri.toString(), response.statusCode,
          body: response.body);

      return _handleResponse(response, endpoint);
    } on SocketException {
      throw NetworkException(
        'No internet connection or server unreachable',
        endpoint: endpoint,
      );
    } on TimeoutException {
      throw NetworkException(
        'Request timeout - server took too long to respond',
        endpoint: endpoint,
      );
    } catch (e) {
      throw NetworkException(
        'PUT request failed: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  /// Generic DELETE request
  Future<http.Response> delete(
    String endpoint, {
    bool requiresAuth = true,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      final baseUrl = await getBaseUrl();
      final uri = Uri.parse('$baseUrl$endpoint');

      _logRequest('DELETE', uri.toString());

      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(timeout);

      _logResponse('DELETE', uri.toString(), response.statusCode,
          body: response.body);

      return _handleResponse(response, endpoint);
    } on SocketException {
      throw NetworkException(
        'No internet connection or server unreachable',
        endpoint: endpoint,
      );
    } on TimeoutException {
      throw NetworkException(
        'Request timeout - server took too long to respond',
        endpoint: endpoint,
      );
    } catch (e) {
      throw NetworkException(
        'DELETE request failed: ${e.toString()}',
        endpoint: endpoint,
      );
    }
  }

  /// Handle response and throw appropriate exceptions
  http.Response _handleResponse(http.Response response, String endpoint) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    // Handle specific HTTP status codes
    switch (response.statusCode) {
      case 400:
        throw NetworkException(
          'Bad request - invalid data sent',
          statusCode: 400,
          endpoint: endpoint,
        );
      case 401:
        throw NetworkException(
          'Unauthorized - please log in again',
          statusCode: 401,
          endpoint: endpoint,
        );
      case 403:
        throw NetworkException(
          'Forbidden - you don\'t have permission',
          statusCode: 403,
          endpoint: endpoint,
        );
      case 404:
        throw NetworkException(
          'Not found - endpoint does not exist',
          statusCode: 404,
          endpoint: endpoint,
        );
      case 500:
        throw NetworkException(
          'Server error - please try again later',
          statusCode: 500,
          endpoint: endpoint,
        );
      default:
        throw NetworkException(
          'HTTP error ${response.statusCode}',
          statusCode: response.statusCode,
          endpoint: endpoint,
        );
    }
  }

  /// Save auth token securely
  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  /// Clear auth token (logout)
  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  /// Check if user has valid auth token
  Future<bool> hasAuthToken() async {
    final token = await _getAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Dispose and cleanup
  void dispose() {
    _client?.close();
    _client = null;
  }
}
