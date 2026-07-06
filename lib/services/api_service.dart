import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'http_client_wrapper.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/product.dart';
import '../models/table.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';
import '../models/pos_tax_config.dart';
import '../models/chat_message.dart';
import 'network_service.dart';

class ApiService {
  /// Key used to store the dev IP override in SharedPreferences.
  static const String devBaseUrlKey = 'dev_base_url_override';
  static const String devDbNameKey = 'dev_db_name_override';

  final NetworkService _network = NetworkService();

  String get baseUrl {
    // Get from .env file - MUST be configured
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl == null || envUrl.isEmpty) {
      throw Exception('API_BASE_URL not set in .env file');
    }
    if (Platform.isAndroid && envUrl.contains('localhost')) {
      return envUrl.replaceAll('localhost', '10.0.2.2');
    }
    return envUrl;
  }

  Future<Map<String, dynamic>> fetchMaintenanceStatus() async {
    try {
      final response = await _network.get('/pos/maintenance/status',
          requiresAuth: false, timeout: const Duration(seconds: 5));
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status'] == 'success') {
        return jsonResponse['data'];
      }
    } on NetworkException catch (e) {
      _d('[API ERROR] Failed to fetch maintenance status: $e');
    } catch (e) {
      _d('[API ERROR] Failed to fetch maintenance status: $e');
    }
    return {'is_active': false};
  }

  Future<Map<String, dynamic>> fetchPrivacyPolicy() async {
    try {
      final response = await _network.get('/privacy-policy',
          requiresAuth: false, timeout: const Duration(seconds: 10));
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      _d('[API ERROR] Failed to fetch privacy policy: $e');
      rethrow;
    }
  }

  Future<void> sendHeartbeat({bool isNewSession = false}) async {
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;

      if (userId == 0) return;

      final response = await _network.post(
        '/pos/heartbeat',
        body: {
          'user_id': userId,
          if (isNewSession) 'is_login': true,
        },
        timeout: const Duration(seconds: 5),
      );

      _d(
        '[HEARTBEAT] Sent for user $userId | New Session: $isNewSession | Status: ${response.statusCode}',
      );
    } on NetworkException catch (e) {
      _d('[HEARTBEAT ERROR] $e');
    } catch (e) {
      _d('[HEARTBEAT ERROR] $e');
    }
  }

  Future<void> setAppActiveStatus({required bool isActive}) async {
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;

      if (userId == 0) return;

      final response = await _network.post(
        '/pos/app_active',
        body: {
          'user_id': userId,
          'is_active': isActive,
        },
        timeout: const Duration(seconds: 5),
      );

      _d('[APP ACTIVE] Status $isActive sent for user $userId | API Status: ${response.statusCode}');
    } on NetworkException catch (e) {
      _d('[APP ACTIVE ERROR] $e');
    } catch (e) {
      _d('[APP ACTIVE ERROR] $e');
    }
  }

  /// Async version that respects the dev IP override saved in prefs.
  Future<String> getBaseUrl() async {
    return _network.getBaseUrl();
  }

  /// Resolves the Odoo database name:
  /// 1) dev override from login dev tools
  /// 2) .env API_DB
  /// 3) null (backend will use db_monodb())
  Future<String?> getDatabaseName() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(devDbNameKey)?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }

    final envDb = dotenv.env['API_DB']?.trim();
    if (envDb != null && envDb.isNotEmpty) {
      return envDb;
    }
    return null;
  }

  String resolveMediaUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return '';
    final contentMatch = RegExp(
      r'^/web/content/(\d+)(\?.*)?$',
    ).firstMatch(normalized);
    if (contentMatch != null) {
      normalized = '/web/image/ir.attachment/${contentMatch.group(1)}/datas';
    }
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    final origin = Uri.parse(baseUrl).origin;
    final relative = normalized.startsWith('/') ? normalized : '/$normalized';
    return '$origin$relative';
  }

  void _d(String message) {
    if (!kDebugMode) return;
    developer.log(message, name: 'ApiService');
  }

  /// Sum `price_unit * qty` for a cached `lines` array (open ticket JSON).
  double _sumCachedOpenTicketLinesAmount(dynamic lineList) {
    if (lineList is! List) return 0.0;
    var sum = 0.0;
    for (final raw in lineList) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final pu = (m['price_unit'] is num)
          ? (m['price_unit'] as num).toDouble()
          : double.tryParse(m['price_unit']?.toString() ?? '') ?? 0.0;
      final q = (m['qty'] is int)
          ? (m['qty'] as int)
          : (m['qty'] is num)
          ? (m['qty'] as num).toInt()
          : int.tryParse(m['qty']?.toString() ?? '1') ?? 1;
      sum += pu * q;
    }
    return sum;
  }

  /// Compute total after applying discount, matching the frontend's [computePosDiscount].
  double _discountedTotal(
    double subtotal,
    String? discountType,
    double? discountValue,
  ) {
    if (discountType == null || discountValue == null || discountValue <= 0) {
      return subtotal;
    }
    if (discountType == 'percentage') {
      final pct = discountValue.clamp(0.0, 100.0);
      return subtotal - (subtotal * pct / 100.0);
    }
    final amount = discountValue.clamp(0.0, subtotal);
    return subtotal - amount;
  }

  /// After offline `create` syncs, replace mock id in cache with real Odoo id
  /// so Open Tickets does not list both OFFLINE-MOCK and POS/… for one order.
  Future<void> _remapCachedOpenTicketMockId({
    required int mockId,
    required int realId,
    required Map<String, dynamic> jsonResp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_open_tickets');
    if (cached == null) return;
    final list = List<dynamic>.from(jsonDecode(cached));
    final idx = list.indexWhere((e) => e is Map && (e)['id'] == mockId);
    if (idx < 0) return;
    final m = Map<String, dynamic>.from(list[idx] as Map);
    m['id'] = realId;
    final data = jsonResp['data'];
    if (data is Map) {
      if (data['order_reference'] != null) {
        m['name'] = data['order_reference'].toString();
      } else if (data['name'] != null) {
        m['name'] = data['name'].toString();
      }
    }
    list[idx] = m;
    await prefs.setString('cached_open_tickets', jsonEncode(list));
    _d(
      '[OFFLINE SYNC] remapped open ticket in cache: mockId=$mockId -> $realId',
    );
  }

  /// Async variant that respects dev base URL override from SharedPreferences.
  Future<String> resolveMediaUrlAsync(String rawUrl) async {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return '';
    final contentMatch = RegExp(
      r'^/web/content/(\d+)(\?.*)?$',
    ).firstMatch(normalized);
    if (contentMatch != null) {
      normalized = '/web/image/ir.attachment/${contentMatch.group(1)}/datas';
    }
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }
    final base = await getBaseUrl();
    final origin = Uri.parse(base).origin;
    final relative = normalized.startsWith('/') ? normalized : '/$normalized';
    return '$origin$relative';
  }

  Future<Map<String, String>> buildImageHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('cached_user_session');
    if (sessionId == null || sessionId.isEmpty) {
      return const {};
    }
    return {
      // Some environments are strict about Cookie formatting; keep a trailing ';'
      // to reduce "cookie ignored" edge cases.
      'Cookie': 'session_id=$sessionId;',
      'X-Openerp-Session-Id': sessionId,
    };
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('cached_user_session');
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['Cookie'] = 'session_id=$sessionId;';
      headers['X-Openerp-Session-Id'] = sessionId;
    }
    return headers;
  }

  Future<void> _updateCacheList(String key, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    // Always create list even if cache doesn't exist yet
    final list = cached != null
        ? List<dynamic>.from(jsonDecode(cached))
        : <dynamic>[];
    final index = list.indexWhere(
      (e) => e != null && e is Map && e['id'] == item['id'],
    );
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _removeFromCacheList(String key, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null) {
      final list = List<dynamic>.from(jsonDecode(cached));
      list.removeWhere((e) => e != null && e is Map && e['id'] == id);
      await prefs.setString(key, jsonEncode(list));
    }
  }

  Future<void> _markTableHasOpenOrder(
    int tableId, {
    required bool hasOpenOrder,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_tables');
    if (cached == null) return;

    try {
      final list = List<dynamic>.from(jsonDecode(cached));
      final idx = list.indexWhere(
        (e) => e != null && e is Map && e['id'] == tableId,
      );
      if (idx < 0) return;

      final current = Map<String, dynamic>.from(list[idx] as Map);
      current['has_open_order'] = hasOpenOrder;
      list[idx] = current;
      await prefs.setString('cached_tables', jsonEncode(list));
    } catch (_) {
      // ignore cache corruption; caller will rely on server refresh
    }
  }

  /// Returns cached products instantly (null if no cache)
  Future<List<Product>?> getCachedProducts({int? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = branchId != null ? 'cached_products_$branchId' : 'cached_products';
    final cached = prefs.getString(cacheKey);
    if (cached == null) return null;
    final List<dynamic> data = jsonDecode(cached);
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> fetchProducts({
    int? branchId,
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = branchId != null ? 'cached_products_$branchId' : 'cached_products';
    if (!forceRefresh) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => Product.fromJson(json)).toList();
      }
    }

    final base = await getBaseUrl();

    try {
      final queryParams = branchId != null ? '&branch_id=$branchId' : '';
      final url = Uri.parse('$base/products?limit=$limit&offset=$offset$queryParams');
      _d('==============================');
      _d('[API CALL] GET $url');

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      _d('[API RESP] GET $url | STATUS: ${response.statusCode}');
      _d('[API BODY] ${response.body}');
      _d('==============================');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'];
          await prefs.setString(cacheKey, jsonEncode(data));
          return data.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception(
            jsonResponse['message'] ?? 'Failed to load products from server',
          );
        }
      } else {
        throw Exception(
          'Failed to connect to Odoo Server (Code: ${response.statusCode})',
        );
      }
    } catch (e) {
      _d(
        '[API OFFLINE] Fetch products failed. Falling back to cache. Error: $e',
      );
      final cachedProducts = prefs.getString(cacheKey);
      if (cachedProducts != null) {
        final List<dynamic> data = jsonDecode(cachedProducts);
        return data.map((json) => Product.fromJson(json)).toList();
      }
      throw Exception(
        'No internet connection and no offline cached products available.',
      );
    }
  }

  Future<Map<String, List<int>>> fetchProductHighlights({int? branchId}) async {
    final base = await getBaseUrl();
    try {
      final queryParams = branchId != null ? '?branch_id=$branchId' : '';
      final url = Uri.parse('$base/pos/products/highlights$queryParams');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final data = jsonResponse['data'];
          return {
            'recommended': List<int>.from(data['recommended_ids'] ?? []),
            'popular': List<int>.from(data['popular_ids'] ?? []),
          };
        }
      }
    } catch (e) {
      _d('[API ERROR] Failed to fetch product highlights: $e');
    }
    return {'recommended': [], 'popular': []};
  }

  /// Returns cached tables instantly (null if no cache)
  Future<List<PosTable>?> getCachedTables() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_tables');
    if (cached == null) return null;
    final List<dynamic> data = jsonDecode(cached);
    return data.map((json) => PosTable.fromJson(json)).toList();
  }

  Future<List<PosTable>> fetchTables({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_tables');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => PosTable.fromJson(json)).toList();
      }
    }

    final base = await getBaseUrl();

    try {
      final branchId = await getCachedBranchId();
      final url = Uri.parse('$base/pos/tables').replace(
        queryParameters: (branchId != null && branchId > 0)
            ? {'branch_id': '$branchId'}
            : null,
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'];
          await prefs.setString('cached_tables', jsonEncode(data));
          return data.map((json) => PosTable.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load tables');
    } catch (e) {
      final cachedStr = prefs.getString('cached_tables');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => PosTable.fromJson(json)).toList();
      }
      return [];
    }
  }

  /// Returns cached payment methods instantly (null if no cache)
  Future<List<PaymentMethod>?> getCachedPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_payment_methods');
    if (cached == null) return null;
    final List<dynamic> data = jsonDecode(cached);
    return data.map((json) => PaymentMethod.fromJson(json)).toList();
  }

  Future<List<PaymentMethod>> fetchPaymentMethods({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_payment_methods');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => PaymentMethod.fromJson(json)).toList();
      }
    }

    final base = await getBaseUrl();

    try {
      final url = Uri.parse('$base/pos/payment_methods');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'];
          await prefs.setString('cached_payment_methods', jsonEncode(data));
          return data.map((json) => PaymentMethod.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load payment methods');
    } catch (e) {
      final cachedStr = prefs.getString('cached_payment_methods');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => PaymentMethod.fromJson(json)).toList();
      }
      return [];
    }
  }

  /// When the device comes back online, `GET /pos/open_tickets` replaces
  /// `cached_open_tickets` and would drop not-yet-synced offline mock tickets
  /// (negative ids). Re-merge those local draft rows on top of the server list.
  List<dynamic> _mergeLocalDraftOpenTickets(
    List<dynamic> serverList,
    String? previousCacheJson,
  ) {
    if (previousCacheJson == null || previousCacheJson.isEmpty) {
      return List<dynamic>.from(serverList);
    }
    List<dynamic> previous;
    try {
      previous = jsonDecode(previousCacheJson) as List<dynamic>;
    } catch (_) {
      return List<dynamic>.from(serverList);
    }
    final serverIds = <int>{};
    for (final e in serverList) {
      if (e is Map && e['id'] is int) {
        serverIds.add(e['id'] as int);
      } else if (e is Map && e['id'] != null) {
        final p = int.tryParse(e['id'].toString());
        if (p != null) serverIds.add(p);
      }
    }
    final out = List<dynamic>.from(serverList);
    for (final e in previous) {
      if (e is! Map) continue;
      final id = e['id'];
      final int? pid = id is int ? id : int.tryParse(id?.toString() ?? '');
      if (pid == null) continue;
      if (pid >= 0) continue; // only preserve offline / mock rows
      if (serverIds.contains(pid)) continue;
      final st = (e['state'] ?? '').toString().toLowerCase();
      if (st == 'paid' || st == 'done' || e['is_paid'] == true) {
        continue;
      }
      out.add(e);
    }
    return out;
  }

  Future<List<OpenTicket>> fetchOpenTickets({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_open_tickets');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data
            .map(
              (e) => OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
    }

    final base = await getBaseUrl();
    final prevOpenTickets = prefs.getString('cached_open_tickets');
    try {
      // Filter by cashier's branch so each POS only sees its own tickets.
      final branchId = await getCachedBranchId();
      final uri = Uri.parse('$base/pos/open_tickets').replace(
        queryParameters: (branchId != null && branchId > 0)
            ? {'branch_id': '$branchId'}
            : null,
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'] as List<dynamic>;
          final merged = _mergeLocalDraftOpenTickets(data, prevOpenTickets);
          await prefs.setString('cached_open_tickets', jsonEncode(merged));
          return merged
              .map(
                (e) => OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }
      }
      throw Exception('Failed to load tickets');
    } catch (e) {
      final cachedStr = prefs.getString('cached_open_tickets');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr) as List<dynamic>;
        return data
            .map(
              (e) => OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceiptHistory({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (forceRefresh) {
      await prefs.remove('cached_receipt_history');
    } else {
      final cachedStr = prefs.getString('cached_receipt_history');
      if (cachedStr != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
      }
    }

    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/history',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final data = List<Map<String, dynamic>>.from(jsonResponse['data']);
          await prefs.setString('cached_receipt_history', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load receipt history');
    } catch (e) {
      final cachedStr = prefs.getString('cached_receipt_history');
      if (cachedStr != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
      }
      return [];
    }
  }

  /// Paginated receipt history fetch - optimized for large datasets
  /// Uses LIMIT and OFFSET for efficient database queries
  Future<ReceiptHistoryResult> fetchReceiptHistoryPaginated({
    required int limit,
    required int offset,
  }) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;

      final queryParams = <String, String>{
        'limit': '$limit',
        'offset': '$offset',
      };
      if (userId > 0) {
        queryParams['user_id'] = '$userId';
      }

      final url = Uri.parse(
        '$base/pos/history/paginated',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final data = jsonResponse['data'];
          final receipts = List<Map<String, dynamic>>.from(
            data['receipts'] ?? [],
          );
          final hasMore = data['has_more'] == true || data['hasMore'] == true;
          final totalCount = data['total_count'] ?? data['totalCount'] ?? 0;

          return ReceiptHistoryResult(
            receipts: receipts,
            hasMore: hasMore,
            totalCount: totalCount,
          );
        }
      }
      throw Exception('Failed to load receipt history');
    } catch (e) {
      throw Exception('Failed to load receipt history: $e');
    }
  }

  Future<Map<String, dynamic>> fetchOrderReceipt(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/order/$orderId/receipt',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse['data'];
        }
      }
      throw Exception('Failed to load receipt details');
    } catch (e) {
      throw Exception('Network error: Cannot fetch receipt details');
    }
  }

  Future<Map<String, dynamic>> fetchRiderOrders() async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/rider/orders',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse;
        }
        throw Exception(
          jsonResponse['message'] ?? 'Failed to load rider orders',
        );
      }
      throw Exception('Failed to load rider orders');
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch list of approved riders for a given branch.
  Future<List<dynamic>> fetchRiderList({int? branchId}) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final params = <String, String>{};
      if (userId > 0) params['user_id'] = '$userId';
      if (branchId != null && branchId > 0) params['branch_id'] = '$branchId';
      final url = Uri.parse(
        '$base/pos/rider/list',
      ).replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse['data'] ?? [];
        }
        throw Exception(jsonResponse['message'] ?? 'Failed to load riders');
      }
      throw Exception('Failed to load riders');
    } catch (e) {
      rethrow;
    }
  }

  /// Assign a rider to a paid order.
  Future<Map<String, dynamic>> assignRider({
    required int orderId,
    required int riderId,
  }) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/order/$orderId/assign_rider',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode({'rider_id': riderId}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse;
        }
        throw Exception(jsonResponse['message'] ?? 'Failed to assign rider');
      }
      throw Exception('Failed to assign rider');
    } catch (e) {
      rethrow;
    }
  }

  /// Rider marks arrival at customer location.
  Future<Map<String, dynamic>> riderArrived(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/order/$orderId/rider_arrived',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .post(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse;
        }
        throw Exception(jsonResponse['message'] ?? 'Failed to mark arrived');
      }
      throw Exception('Failed to mark arrived');
    } catch (e) {
      rethrow;
    }
  }

  /// Rider marks delivery as complete.
  Future<Map<String, dynamic>> riderComplete(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/order/$orderId/rider_complete',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      final response = await http
          .post(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return jsonResponse;
        }
        throw Exception(
          jsonResponse['message'] ?? 'Failed to complete delivery',
        );
      }
      throw Exception('Failed to complete delivery');
    } catch (e) {
      rethrow;
    }
  }

  /// Rider sends GPS location to backend (called every 5s).
  Future<void> riderUpdateLocation({
    required int orderId,
    required double latitude,
    required double longitude,
  }) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final url = Uri.parse(
        '$base/pos/rider/location',
      ).replace(queryParameters: userId > 0 ? {'user_id': '$userId'} : null);
      await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode({
              'order_id': orderId,
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silent fail — location updates are best-effort
    }
  }

  /// Fetch the latest rider location for an order.
  /// GET `/api/pos/order/:id/rider_location`
  Future<Map<String, dynamic>?> fetchRiderLocation(String orderId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/rider_location');
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] != null) {
          return Map<String, dynamic>.from(jsonResponse['data']);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the selected/default bill template for printing.
  /// Backend: GET `/api/pos/bill_template?type=bill|receipt|refund`
  Future<Map<String, dynamic>> fetchBillTemplate({
    String type = 'receipt',
    bool forceRefresh = false,
  }) async {
    // Try cache first (fast UI), then network.
    if (!forceRefresh) {
      final cached = await getCachedBillTemplate(type: type);
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final base = await getBaseUrl();
    final user = await getCachedUser();
    final userId = (user != null && user['user_id'] != null)
        ? (user['user_id'] is int
              ? user['user_id'] as int
              : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
        : 0;
    final sid = await getCachedSessionId() ?? '';
    final url = Uri.parse('$base/pos/bill_template').replace(
      queryParameters: {
        'type': type,
        if (userId > 0) 'user_id': '$userId',
        if (sid.isNotEmpty) 'session_id': sid,
      },
    );
    final response = await http
        .get(url, headers: await _authHeaders(json: true))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw Exception('Failed to load bill template (${response.statusCode})');
    }
    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse is Map && jsonResponse['status'] == 'success') {
      final data = jsonResponse['data'];
      if (data is Map) {
        final out = Map<String, dynamic>.from(data);
        await _setCachedBillTemplate(type: type, data: out);
        return out;
      }
    }
    throw Exception('Failed to load bill template');
  }

  /// List templates for selection in POS.
  /// Backend: GET `/api/pos/bill_templates?type=bill|receipt|refund`
  Future<List<Map<String, dynamic>>> fetchBillTemplates({
    String? type,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await getCachedBillTemplates(type: type ?? '');
      if (cached != null && cached.isNotEmpty) return cached;
    }
    final base = await getBaseUrl();
    final user = await getCachedUser();
    final userId = (user != null && user['user_id'] != null)
        ? (user['user_id'] is int
              ? user['user_id'] as int
              : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
        : 0;
    final sid = await getCachedSessionId() ?? '';
    final qp = <String, String>{
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (userId > 0) 'user_id': '$userId',
      if (sid.isNotEmpty) 'session_id': sid,
    };
    final url = Uri.parse(
      '$base/pos/bill_templates',
    ).replace(queryParameters: qp.isEmpty ? null : qp);
    final response = await http
        .get(url, headers: await _authHeaders(json: true))
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) {
      throw Exception('Failed to load bill templates (${response.statusCode})');
    }
    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse is Map && jsonResponse['status'] == 'success') {
      final raw = jsonResponse['data'];
      if (raw is List) {
        final out = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        await _setCachedBillTemplates(type: type ?? '', data: out);
        return out;
      }
    }
    throw Exception('Failed to load bill templates');
  }

  // ---------------------------------------------------------------------------
  // BILL TEMPLATE CACHE (UI speed)
  // ---------------------------------------------------------------------------

  String _billTemplatesKey(String type) =>
      'cached_bill_templates_${type.trim().toLowerCase()}';
  String _billTemplateKey(String type) =>
      'cached_bill_template_${type.trim().toLowerCase()}';

  Future<List<Map<String, dynamic>>?> getCachedBillTemplates({
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_billTemplatesKey(type));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getCachedBillTemplate({
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_billTemplateKey(type));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> _setCachedBillTemplates({
    required String type,
    required List<Map<String, dynamic>> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_billTemplatesKey(type), jsonEncode(data));
  }

  Future<void> _setCachedBillTemplate({
    required String type,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_billTemplateKey(type), jsonEncode(data));
  }

  /// Admin-only: set templates for this admin's branch.
  /// Backend: POST `/api/pos/branch/templates`
  Future<void> setBranchBillTemplates({
    int? billTemplateId,
    int? receiptTemplateId,
    int? refundTemplateId,
    int? kitchenTemplateId,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/branch/templates');

    // Include user_id + session_id in the body so the backend can authenticate
    // even when cookies don't reach the server (e.g. ngrok / proxy setups).
    final user = await getCachedUser();
    final userId = (user != null && user['user_id'] != null)
        ? (user['user_id'] is int
              ? user['user_id'] as int
              : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
        : 0;
    final sid = await getCachedSessionId() ?? '';

    final payload = <String, dynamic>{
      if (billTemplateId != null) 'bill_template_bill_id': billTemplateId,
      if (receiptTemplateId != null)
        'bill_template_receipt_id': receiptTemplateId,
      if (refundTemplateId != null) 'bill_template_refund_id': refundTemplateId,
      if (kitchenTemplateId != null)
        'bill_template_kitchen_id': kitchenTemplateId,
      if (userId > 0) 'user_id': userId,
      if (sid.isNotEmpty) 'session_id': sid,
    };
    final response = await http
        .post(
          url,
          headers: await _authHeaders(json: true),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 &&
        jsonResponse is Map &&
        jsonResponse['status'] == 'success') {
      return;
    }
    throw Exception(
      jsonResponse is Map ? (jsonResponse['message'] ?? 'Failed') : 'Failed',
    );
  }

  // ---------------------------------------------------------------------------
  // ADMIN REPORTS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> fetchAdminReportSummary({
    required DateTime from,
    required DateTime to,
    int? branchId,
  }) async {
    final base = await getBaseUrl();

    // Belt-and-suspenders: also pass user_id + session_id as query params so the
    // backend can authenticate even when the session cookie is dropped by
    // tunnels/proxies (ngrok, etc). Backend prefers the cookie path and falls
    // back to user_id+session_id if matching `pos_admin_active_sid`.
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString('cached_user_session') ?? '';
    final user = await getCachedUser();
    final userId = (user != null && user['user_id'] != null)
        ? (user['user_id'] is int
              ? user['user_id'] as int
              : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
        : 0;

    final tzOffset = DateTime.now().timeZoneOffset.inMinutes / 60.0;

    final url = Uri.parse('$base/pos/reports/summary').replace(
      queryParameters: {
        'from': DateFormat('yyyy-MM-dd').format(from),
        'to': DateFormat('yyyy-MM-dd').format(to),
        if (branchId != null && branchId > 0) 'branch_id': '$branchId',
        if (userId > 0) 'user_id': '$userId',
        if (sid.isNotEmpty) 'session_id': sid,
        'tz_offset': '$tzOffset',
      },
    );
    final resp = await http
        .get(url, headers: await _authHeaders(json: true))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load reports (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map || decoded['status']?.toString() != 'success') {
      throw Exception(
        decoded is Map ? (decoded['message'] ?? 'Failed') : 'Failed',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String login,
    required String password,
    required String role,
    String? phone,
    int? branchId,
    String? authProvider,
    String? otpCode,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/register');
    final Map<String, dynamic> payload = {
      'name': name,
      'login': login,
      'password': password,
      'role': role,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if ((role == 'cashier' || role == 'rider') &&
          branchId != null &&
          branchId > 0)
        'branch_id': branchId,
      if (authProvider != null && authProvider.trim().isNotEmpty)
        'auth_provider': authProvider.trim(),
      if (otpCode != null && otpCode.trim().isNotEmpty)
        'otp_code': otpCode.trim(),
    };
    _d('==============================');
    _d('[API CALL] POST $url');
    _d('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
    _d('[API BODY] ${response.body}');
    _d('==============================');

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
      return jsonResponse;
    } else {
      throw Exception(jsonResponse['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/otp/send');
    final payload = {
      'phone': phone.trim(),
    };

    _d('==============================');
    _d('[API CALL] POST $url');
    _d('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
    _d('[API BODY] ${response.body}');
    _d('==============================');

    try {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse is Map) {
        return Map<String, dynamic>.from(jsonResponse);
      }
    } catch (_) {}
    return {
      'status': 'error',
      'message': 'Failed to send OTP (${response.statusCode})',
    };
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otpCode) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/otp/verify');
    final payload = {
      'phone': phone.trim(),
      'otp_code': otpCode.trim(),
    };

    _d('==============================');
    _d('[API CALL] POST $url');
    _d('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
    _d('[API BODY] ${response.body}');
    _d('==============================');

    try {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse is Map) {
        return Map<String, dynamic>.from(jsonResponse);
      }
    } catch (_) {}
    return {
      'status': 'error',
      'message': 'Failed to verify OTP (${response.statusCode})',
    };
  }

  Future<Map<String, dynamic>> loginUser(
    String login,
    String password, {
    String? authProvider,
    bool force = false,
  }) async {
    final dbName = await getDatabaseName();
    final normalizedLogin = login.trim().toLowerCase();
    final device = await _collectDeviceInfo();
    final Map<String, dynamic> payload = {
      if (dbName != null && dbName.trim().isNotEmpty) 'db': dbName.trim(),
      'login': normalizedLogin,
      'password': password,
      'device_id': device['device_id'],
      'platform': device['platform'],
      'device_name': device['device_name'],
      'model': device['model'],
      'manufacturer': device['manufacturer'],
      'brand': device['brand'],
      if (authProvider != null && authProvider.trim().isNotEmpty)
        'auth_provider': authProvider.trim(),
      if (force) 'force': true,
    };

    try {
      final response = await _network.post(
        '/pos/login',
        body: payload,
        requiresAuth: false,
        throwOnError: false,
      );

      final jsonResponse = jsonDecode(response.body);

      // HTTP 409 → another device has an active session.
      // Return a structured map so the caller can show a conflict dialog.
      if (response.statusCode == 409 &&
          (jsonResponse['status']?.toString() == 'conflict')) {
        final conflictData =
            (jsonResponse['data'] is Map)
                ? Map<String, dynamic>.from(jsonResponse['data'] as Map)
                : <String, dynamic>{};
        return {
          'status': 'conflict',
          'message': jsonResponse['message']?.toString() ?? 'Session conflict',
          ...conflictData,
        };
      }

      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
      final data = jsonResponse['data'];
      final sessionId = jsonResponse['session_id'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_session', sessionId ?? '');
      await prefs.setString('cached_user_data', jsonEncode(data));

      // Cache branch from backend profile (cashier/admin)
      try {
        if (data is Map) {
          final branchId = (data['branch_id'] is int)
              ? data['branch_id'] as int
              : int.tryParse(data['branch_id']?.toString() ?? '');
          final branchName = (data['branch_name'] ?? '').toString();
          if (branchId != null && branchId > 0) {
            await setCachedBranch(branchId: branchId, branchName: branchName);
          } else if (branchName.trim().isNotEmpty) {
            await setCachedBranch(branchId: null, branchName: branchName);
          }
        }
      } catch (_) {}

      // Cashier: force POS name prompt once per login session.
      try {
        final role = (data is Map) ? (data['role']?.toString()) : null;
        final sid = (sessionId ?? '').toString().trim();
        if (role == 'cashier' && sid.isNotEmpty) {
          await prefs.setString(_posIdentityPromptSessionKey, sid);
        }
      } catch (_) {}

      // Customer: silently log device on login for audit trail.
      // Backend requires non-empty `pos_name`, but customers don't pick a POS name,
      // so use a stable label for self-order devices.
      try {
        final role = (data is Map) ? (data['role']?.toString()) : null;
        if (role == 'customer' && data is Map) {
          final userId = (data['user_id'] is int)
              ? data['user_id'] as int
              : int.tryParse(data['user_id']?.toString() ?? '') ?? 0;
          final name = (data['name'] ?? 'Customer').toString();
          if (userId > 0) {
            Future(() async {
              try {
                await registerPosDevice(
                  userId: userId,
                  cashierName: name,
                  posName: 'SelfOrder',
                  branchId: await getCachedBranchId(),
                  branchName: await getCachedBranchName(),
                );
              } catch (_) {}
            });
          }
        }
      } catch (_) {}

      return data;
    } else {
      throw Exception(jsonResponse['message'] ?? 'Login failed');
    }
    } on NetworkException catch (e) {
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cached_user_data');
    if (data != null && data.isNotEmpty) {
      return jsonDecode(data);
    }
    return null;
  }

  /// Branch tax flags from login payload (`tax_active`, `tax_percent`, `tax_inclusive`).
  Future<PosTaxConfig> getPosTaxConfig() async {
    final u = await getCachedUser();
    return PosTaxConfig.fromLoginJson(u);
  }

  /// Cashier id + device UTC time for Odoo security audit (void ticket / refund).
  Future<Map<String, dynamic>> _cashierAuditFields() async {
    final user = await getCachedUser();
    int? uid;
    if (user != null && user['user_id'] != null) {
      final v = user['user_id'];
      uid = v is int ? v : int.tryParse(v.toString());
      if (uid != null && uid <= 0) uid = null;
    }
    return {
      if (uid != null) 'user_id': uid,
      'client_timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_session');
    await prefs.remove('cached_user_data');
    await prefs.remove(_posIdentityPromptSessionKey);
  }

  /// Customer: validate that current session is still active.
  /// Backend endpoint: POST `/api/pos/session/validate`
  Future<bool> validateCustomerSession() async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/session/validate');
    final headers = await _authHeaders(json: true);
    final user = await getCachedUser();
    final userId = (user != null && user['user_id'] != null)
        ? (user['user_id'] is int
              ? user['user_id'] as int
              : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
        : 0;
    final sid = await getCachedSessionId() ?? '';
    final device = await getDeviceInfoForAudit();
    final response = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode({
            'user_id': userId,
            'session_id': sid,
            'device_id': device['device_id'],
          }),
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) return true;
    return false;
  }

  Future<void> setPosPin(String pin, int userId) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/set_pin');

    _d('==============================');
    _d('[SET PIN] POST $url');
    _d('[SET PIN] user_id: $userId | pin: $pin');

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
          }, // ← no session needed now
          body: jsonEncode({'pin': pin, 'user_id': userId}),
        )
        .timeout(const Duration(seconds: 6));

    _d('[SET PIN] STATUS: ${response.statusCode}');
    _d('[SET PIN] BODY: ${response.body}');
    _d('==============================');

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
      throw Exception(jsonResponse['message'] ?? 'Failed to save PIN');
    }

    // Update local cache
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_user_data');
    if (cached != null && cached.isNotEmpty) {
      final data = Map<String, dynamic>.from(jsonDecode(cached));
      data['pos_pin'] = pin;
      await prefs.setString('cached_user_data', jsonEncode(data));
    }
  }

  Future<Map<String, dynamic>> submitOrder({
    required int userId,
    int? partnerId,
    int? tableId,
    int? paymentMethodId,
    String paymentType = 'pay_at_store',
    bool isPaid = false,
    required List<Map<String, dynamic>> lines,
    int? branchId,
    String? customerName,
    String? customerPhone,
    String? note,
    String? deliveryPlaceName,
    String? deliveryPlaceAddress,
    String? deliveryPlaceId,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? deliveryMapsUrl,
    String? discountType,
    double? discountValue,
    String? couponCode,
    double? deliveryFee,
  }) async {
    final base = await getBaseUrl();
    final cn = customerName?.trim() ?? '';
    final cp = _cleanOptionalText(customerPhone);
    final payload = {
      'user_id': userId,
      'partner_id': partnerId,
      'table_id': tableId,
      'payment_method_id': paymentMethodId,
      'payment_type': paymentType,
      'is_paid': isPaid,
      'lines': lines,
      if (branchId != null && branchId > 0) 'branch_id': branchId,
      if (cn.isNotEmpty) 'customer_name': cn,
      if (cp.isNotEmpty) 'customer_phone': cp,
      if (note != null && note.isNotEmpty) 'note': note,
      if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      if ((deliveryPlaceName ?? '').trim().isNotEmpty)
        'delivery_place_name': deliveryPlaceName!.trim(),
      if ((deliveryPlaceAddress ?? '').trim().isNotEmpty)
        'delivery_place_address': deliveryPlaceAddress!.trim(),
      if ((deliveryPlaceId ?? '').trim().isNotEmpty)
        'delivery_place_id': deliveryPlaceId!.trim(),
      if (deliveryLatitude != null) 'delivery_latitude': deliveryLatitude,
      if (deliveryLongitude != null) 'delivery_longitude': deliveryLongitude,
      if ((deliveryMapsUrl ?? '').trim().isNotEmpty)
        'delivery_maps_url': deliveryMapsUrl!.trim(),
      if (discountType != null &&
          discountValue != null &&
          discountValue > 0) ...{
        'discount_type': discountType,
        'discount_value': discountValue,
      },
      if (deliveryFee != null && deliveryFee > 0) 'delivery_fee': deliveryFee,
    };

    try {
      final url = Uri.parse('$base/pos/order');
      _d('==============================');
      _d('[API CALL] POST $url');
      _d('[API LOAD] $payload');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
      _d('[API BODY] ${response.body}');
      _d('==============================');

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final raw = jsonResponse['data'];
        final data = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        // Some endpoints return order_id but not id; normalize for Receipt History.
        data['id'] ??= data['order_id'];
        await _updateCacheList('cached_receipt_history', data);
        return data;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to submit order');
      }
    } catch (e) {
      _d(
        '[API OFFLINE] Order failed to submit. Saving to offline queue. Error: $e',
      );
      final mockId = -DateTime.now().millisecondsSinceEpoch;
      await _queueOfflineOrder({
        'action': 'submit',
        'payload': payload,
        'mock_id': mockId,
      });
      final now = DateTime.now();
      final rawSubtotal = lines.fold<double>(
        0.0,
        (sum, line) => sum + (line['price_unit'] * line['qty']),
      );
      final discounted = _discountedTotal(
        rawSubtotal,
        discountType,
        discountValue,
      );
      final discountAmount = rawSubtotal - discounted;
      final mockReceipt = {
        'offline': true,
        'synced': false,
        'id': mockId,
        'name': 'OFFLINE-$mockId',
        'order_reference': 'OFFLINE-$mockId',
        'date_order': now.toIso8601String(),
        if (isPaid) 'date_paid': now.toIso8601String(),
        'payment_method': paymentMethodId != null
            ? 'Method #$paymentMethodId'
            : 'Offline',
        'amount_total': discounted,
        'amount_discount': discountAmount,
        'state': isPaid ? 'paid' : 'draft',
      };
      await _updateCacheList('cached_receipt_history', mockReceipt);
      return mockReceipt;
    }
  }

  String _cleanOptionalText(String? value) {
    final text = value?.trim() ?? '';
    final lower = text.toLowerCase();
    if (text.isEmpty ||
        lower == 'false' ||
        lower == 'null' ||
        lower == 'none') {
      return '';
    }
    return text;
  }

  Future<Map<String, dynamic>> createOrder({
    required int userId,
    int? tableId,
    int? customerId,
    String? name,
    int? branchId,
    required List<Map<String, dynamic>> lines,
    String? discountType,
    double? discountValue,
  }) async {
    final base = await getBaseUrl();
    // Use explicitly provided branchId, or fall back to cashier's cached branch.
    final effectiveBranchId = (branchId != null && branchId > 0)
        ? branchId
        : await getCachedBranchId();
    final payload = {
      'user_id': userId,
      if (tableId != null && tableId > 0) 'table_id': tableId,
      if (customerId != null && customerId > 0) 'partner_id': customerId,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (effectiveBranchId != null && effectiveBranchId > 0)
        'branch_id': effectiveBranchId,
      'lines': lines,
      if (discountType != null &&
          discountValue != null &&
          discountValue > 0) ...{
        'discount_type': discountType,
        'discount_value': discountValue,
      },
    };

    try {
      final url = Uri.parse('$base/pos/order');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final data = jsonResponse['data'];
        final subtotal = lines.fold<double>(
          0.0,
          (sum, line) =>
              sum +
              ((line['price_unit'] as num).toDouble() *
                  (line['qty'] as num).toInt()),
        );
        final localTicket = {
          'id': data['order_id'],
          'name': data['order_reference'],
          'table_id': tableId,
          'table_name': tableId != null
              ? 'Table $tableId'
              : (name ?? 'Customer'),
          'amount_total': _discountedTotal(
            subtotal,
            discountType,
            discountValue,
          ),
          'state': 'draft',
          if (discountType != null &&
              discountValue != null &&
              discountValue > 0)
            'discount_type': discountType,
          if (discountType != null &&
              discountValue != null &&
              discountValue > 0)
            'discount_value': discountValue,
          if (effectiveBranchId != null && effectiveBranchId > 0)
            'branch_id': effectiveBranchId,
          // Needed for Open Tickets duration badge (see OpenTicket.openedAt)
          'opened_at': DateTime.now().toUtc().toIso8601String(),
          'lines': lines
              .map(
                (l) => {
                  'product_id': l['product_id'],
                  'product_name': 'Item',
                  'qty': l['qty'],
                  'price_unit': l['price_unit'],
                  'topping_ids': l['topping_ids'] ?? [],
                },
              )
              .toList(),
        };
        await _updateCacheList('cached_open_tickets', localTicket);
        if (tableId != null) {
          await _markTableHasOpenOrder(tableId, hasOpenOrder: true);
        }
        return data;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      final mockId = -DateTime.now().millisecondsSinceEpoch;
      await _queueOfflineOrder({
        'action': 'create',
        'payload': payload,
        'mock_id': mockId,
      });
      final subtotal = lines.fold<double>(
        0.0,
        (sum, line) =>
            sum +
            ((line['price_unit'] as num).toDouble() *
                (line['qty'] as num).toInt()),
      );
      final mockTicket = {
        'id': mockId,
        'name': 'OFFLINE-MOCK', // Using static or mock name
        'table_id': tableId,
        'table_name': tableId != null ? 'Table $tableId' : (name ?? 'Customer'),
        'partner_id': customerId, // keeping for record
        'amount_total': _discountedTotal(subtotal, discountType, discountValue),
        'state': 'draft',
        if (discountType != null && discountValue != null && discountValue > 0)
          'discount_type': discountType,
        if (discountType != null && discountValue != null && discountValue > 0)
          'discount_value': discountValue,
        if (effectiveBranchId != null && effectiveBranchId > 0)
          'branch_id': effectiveBranchId,
        // Needed for Open Tickets duration badge (see OpenTicket.openedAt)
        'opened_at': DateTime.now().toUtc().toIso8601String(),
        'lines': lines
            .map(
              (l) => {
                'product_id': l['product_id'],
                'product_name': 'Item',
                'qty': l['qty'],
                'price_unit': l['price_unit'],
                'topping_ids': l['topping_ids'] ?? [],
              },
            )
            .toList(),
      };
      await _updateCacheList('cached_open_tickets', mockTicket);
      if (tableId != null) {
        await _markTableHasOpenOrder(tableId, hasOpenOrder: true);
      }
      return {'order_id': mockId, 'order_reference': 'OFFLINE-MOCK'};
    }
  }

  Future<Map<String, dynamic>> updateOrder({
    required int orderId,
    int? tableId,
    int? customerId,
    required List<Map<String, dynamic>> lines,
    bool replaceAll = false,
    String? discountType,
    double? discountValue,
  }) async {
    final base = await getBaseUrl();
    final payload = {
      'table_id': tableId,
      'partner_id': customerId,
      'lines': lines,
      if (replaceAll) 'replace_all': true,
      if (discountType != null &&
          discountValue != null &&
          discountValue > 0) ...{
        'discount_type': discountType,
        'discount_value': discountValue,
      },
    };

    try {
      final url = Uri.parse('$base/pos/order/$orderId/update');
      _d('==============================');
      _d('[API CALL] POST $url');
      _d('[API LOAD] $payload');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
      _d('[API BODY] ${response.body}');
      _d('==============================');

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final data = jsonResponse['data'];
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_open_tickets');
        if (cached != null) {
          final list = List<dynamic>.from(jsonDecode(cached));
          final index = list.indexWhere(
            (e) => e != null && e is Map && e['id'] == orderId,
          );
          if (index >= 0) {
            // Ensure existing cached tickets always keep an opened_at timestamp
            // so the Open Tickets screen can show the live duration badge.
            if (list[index] is Map &&
                (list[index]['opened_at'] == null ||
                    (list[index]['opened_at']?.toString().isEmpty ?? true))) {
              list[index]['opened_at'] = DateTime.now()
                  .toUtc()
                  .toIso8601String();
            }

            // If we cleared a ticket completely, remove it from open tickets cache.
            // This also ensures the associated table is selectable again.
            if (replaceAll && lines.isEmpty) {
              list.removeAt(index);
              await prefs.setString('cached_open_tickets', jsonEncode(list));
              if (tableId != null) {
                await _markTableHasOpenOrder(tableId, hasOpenOrder: false);
              }
              return data;
            }

            if (replaceAll) {
              list[index]['lines'] = lines
                  .map(
                    (l) => {
                      'product_id': l['product_id'],
                      'product_name': 'Item',
                      'qty': l['qty'],
                      'price_unit': l['price_unit'],
                      'topping_ids': l['topping_ids'] ?? [],
                    },
                  )
                  .toList();
            } else {
              final existing = List<dynamic>.from(
                list[index]['lines'] ?? const [],
              );
              existing.addAll(
                lines.map(
                  (l) => {
                    'product_id': l['product_id'],
                    'product_name': 'Item',
                    'qty': l['qty'],
                    'price_unit': l['price_unit'],
                    'topping_ids': l['topping_ids'] ?? [],
                  },
                ),
              );
              list[index]['lines'] = existing;
            }
            // Update discount on cached ticket
            if (discountType != null &&
                discountValue != null &&
                discountValue > 0) {
              list[index]['discount_type'] = discountType;
              list[index]['discount_value'] = discountValue;
            }
            // Always total the full ticket, not just this request's new lines
            // (append mode used to set amount_total to "latest lines only").
            final rawSubtotal = _sumCachedOpenTicketLinesAmount(
              list[index]['lines'],
            );
            list[index]['amount_total'] = _discountedTotal(
              rawSubtotal,
              list[index]['discount_type'] as String?,
              (list[index]['discount_value'] as num?)?.toDouble(),
            );
            await prefs.setString('cached_open_tickets', jsonEncode(list));
          }
        }
        return data;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update order');
      }
    } catch (e) {
      await _queueOfflineOrder({
        'action': 'update',
        'payload': payload,
        'mock_id': orderId,
      });
      // Also fetch and update local mock ticket
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_open_tickets');
      if (cached != null) {
        final list = List<dynamic>.from(jsonDecode(cached));
        final index = list.indexWhere(
          (e) => e != null && e is Map && e['id'] == orderId,
        );
        if (index >= 0) {
          if (list[index] is Map &&
              (list[index]['opened_at'] == null ||
                  (list[index]['opened_at']?.toString().isEmpty ?? true))) {
            list[index]['opened_at'] = DateTime.now().toUtc().toIso8601String();
          }

          if (replaceAll && lines.isEmpty) {
            list.removeAt(index);
            await prefs.setString('cached_open_tickets', jsonEncode(list));
            if (tableId != null) {
              await _markTableHasOpenOrder(tableId, hasOpenOrder: false);
            }
            return {'id': orderId, 'cleared_offline': true};
          }

          if (replaceAll) {
            list[index]['lines'] = lines
                .map(
                  (l) => {
                    'product_id': l['product_id'],
                    'product_name': 'Item',
                    'qty': l['qty'],
                    'price_unit': l['price_unit'],
                    'topping_ids': l['topping_ids'] ?? [],
                  },
                )
                .toList();
          } else {
            final existing = List<dynamic>.from(
              list[index]['lines'] ?? const [],
            );
            existing.addAll(
              lines.map(
                (l) => {
                  'product_id': l['product_id'],
                  'product_name': 'Item',
                  'qty': l['qty'],
                  'price_unit': l['price_unit'],
                  'topping_ids': l['topping_ids'] ?? [],
                },
              ),
            );
            list[index]['lines'] = existing;
          }
          if (discountType != null &&
              discountValue != null &&
              discountValue > 0) {
            list[index]['discount_type'] = discountType;
            list[index]['discount_value'] = discountValue;
          }
          final rawSubtotal = _sumCachedOpenTicketLinesAmount(
            list[index]['lines'],
          );
          list[index]['amount_total'] = _discountedTotal(
            rawSubtotal,
            list[index]['discount_type'] as String?,
            (list[index]['discount_value'] as num?)?.toDouble(),
          );
          await prefs.setString('cached_open_tickets', jsonEncode(list));
          return list[index];
        }
      }
      return {'id': orderId, 'offline_update': true};
    }
  }

  Future<Map<String, dynamic>> payOrder({
    required int orderId,
    int? paymentMethodId,
    String? discountType,
    double? discountValue,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/order/$orderId/pay');
    final payload = {
      'payment_method_id': paymentMethodId,
      if (discountType != null &&
          discountValue != null &&
          discountValue > 0) ...{
        'discount_type': discountType,
        'discount_value': discountValue,
      },
    };

    _d('==============================');
    _d('[API CALL] POST $url (PAY)');
    _d('[API LOAD] $payload');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final raw = jsonResponse['data'];
        final data = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        // Some endpoints return order_id but not id; normalize for Receipt History.
        data['id'] ??= data['order_id'] ?? orderId;
        await _removeFromCacheList('cached_open_tickets', orderId);
        await _updateCacheList('cached_receipt_history', data);
        return data;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to pay order');
      }
    } catch (e) {
      // Offline fallback: queue the pay and immediately move the ticket to Receipt History
      // as "Unsynced", while freeing the table locally.
      await _queueOfflineOrder({
        'action': 'pay',
        'payload': payload,
        'mock_id': orderId,
      });

      // Try to extract table + totals from cached_open_tickets so UI looks correct.
      int? tableId;
      String name = 'POS/$orderId';
      double amountTotal = 0.0;
      String dateOrder = DateTime.now().toIso8601String();
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_open_tickets');
        if (cached != null) {
          final list = List<dynamic>.from(jsonDecode(cached));
          final idx = list.indexWhere((t) => t is Map && t['id'] == orderId);
          if (idx >= 0) {
            final t = Map<String, dynamic>.from(list[idx] as Map);
            tableId = t['table_id'] is int ? t['table_id'] as int : null;
            name = (t['name'] ?? name).toString();
            amountTotal = (t['amount_total'] is num)
                ? (t['amount_total'] as num).toDouble()
                : double.tryParse(t['amount_total']?.toString() ?? '') ??
                      amountTotal;
            // If discount wasn't baked into cached amount_total, apply it now
            if (discountType != null &&
                discountValue != null &&
                discountValue > 0) {
              final cachedDiscountType = t['discount_type'] as String?;
              final cachedDiscountValue = (t['discount_value'] as num?)
                  ?.toDouble();
              if (cachedDiscountType != discountType ||
                  cachedDiscountValue != discountValue) {
                final rawSubtotal = _sumCachedOpenTicketLinesAmount(t['lines']);
                amountTotal = _discountedTotal(
                  rawSubtotal,
                  discountType,
                  discountValue,
                );
              }
            }
            dateOrder = (t['opened_at'] ?? t['date_order'] ?? dateOrder)
                .toString();
          }
        }
      } catch (_) {}

      await _removeFromCacheList('cached_open_tickets', orderId);
      if (tableId != null) {
        await _markTableHasOpenOrder(tableId, hasOpenOrder: false);
      }
      // Compute discount amount for offline mock receipt
      double offlineDiscountAmount = 0.0;
      if (discountType != null && discountValue != null && discountValue > 0) {
        double rawSubtotalForDiscount = 0.0;
        try {
          final prefs2 = await SharedPreferences.getInstance();
          final cached2 = prefs2.getString('cached_open_tickets');
          if (cached2 != null) {
            final list2 = List<dynamic>.from(jsonDecode(cached2));
            final idx2 = list2.indexWhere(
              (t) => t is Map && t['id'] == orderId,
            );
            if (idx2 >= 0) {
              final t2 = Map<String, dynamic>.from(list2[idx2] as Map);
              rawSubtotalForDiscount = _sumCachedOpenTicketLinesAmount(
                t2['lines'],
              );
            }
          }
        } catch (_) {}
        if (rawSubtotalForDiscount > 0) {
          final discounted = _discountedTotal(
            rawSubtotalForDiscount,
            discountType,
            discountValue,
          );
          offlineDiscountAmount = rawSubtotalForDiscount - discounted;
        }
      }
      final mockReceipt = {
        'offline': true,
        'synced': false,
        'id': orderId,
        'name': name,
        'order_reference': name,
        'date_order': dateOrder,
        'date_paid': DateTime.now().toIso8601String(),
        'payment_method': paymentMethodId != null
            ? 'Method #$paymentMethodId'
            : 'Offline',
        'state': 'paid',
        'amount_total': amountTotal,
        'amount_discount': offlineDiscountAmount,
      };
      await _updateCacheList('cached_receipt_history', mockReceipt);
      return mockReceipt;
    }
  }

  Future<void> deleteOrderWithAdminPin({
    required int orderId,
    required String adminPin,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/order/$orderId/delete');
    final audit = await _cashierAuditFields();
    final payload = {'admin_pin': adminPin, ...audit};

    _d('==============================');
    _d('[API CALL] POST $url (DELETE ORDER)');
    _d('[API LOAD] $payload');

    final response = await http
        .post(
          url,
          headers: await _authHeaders(json: true),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 5));

    _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
    _d('[API BODY] ${response.body}');
    _d('==============================');

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
      return;
    } else {
      throw Exception(jsonResponse['message'] ?? 'Failed to delete ticket');
    }
  }

  Future<void> refundOrder({
    required int orderId,
    required String adminPin,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/order/$orderId/refund');
    final audit = await _cashierAuditFields();
    final payload = {'admin_pin': adminPin, ...audit};

    final response = await http
        .post(
          url,
          headers: await _authHeaders(json: true),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
      return;
    } else {
      throw Exception(jsonResponse['message'] ?? 'Failed to refund order');
    }
  }

  Future<void> _queueOfflineOrder(Map<String, dynamic> task) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineQueue = prefs.getStringList('offline_orders') ?? [];
    offlineQueue.add(jsonEncode(task));
    await prefs.setStringList('offline_orders', offlineQueue);
  }

  /// Removes queued offline tasks for a specific order id (usually a negative mock id).
  /// This is useful when we want to replace "create + pay" sequences with a single
  /// "submit paid" action for reliability.
  Future<void> purgeOfflineTasksForOrder(int orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final offlineQueue = prefs.getStringList('offline_orders') ?? [];
    if (offlineQueue.isEmpty) return;

    final remaining = <String>[];
    for (final raw in offlineQueue) {
      try {
        final task = jsonDecode(raw);
        if (task is Map) {
          final rawMockId = task['mock_id'];
          final mockId = rawMockId is int
              ? rawMockId
              : int.tryParse(rawMockId?.toString() ?? '');
          if (mockId == orderId) {
            continue; // drop
          }
        }
      } catch (_) {}
      remaining.add(raw);
    }
    await prefs.setStringList('offline_orders', remaining);
  }

  /// Clears a local open ticket from cache and updates table state so the table
  /// is selectable again. Used when an offline ticket is charged and moved into
  /// receipt history "waiting to sync".
  Future<void> clearLocalOpenTicket(int orderId, {int? tableId}) async {
    await _removeFromCacheList('cached_open_tickets', orderId);
    if (tableId != null) {
      await _markTableHasOpenOrder(tableId, hasOpenOrder: false);
    }
  }

  Future<int> syncOfflineOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineQueue = prefs.getStringList('offline_orders') ?? [];

    if (offlineQueue.isEmpty) return 0;

    int syncedCount = 0;
    final base = await getBaseUrl();
    Map<int, int> mockToRealId = {};
    final headers = await _authHeaders(json: true);

    // Multi-pass replay so that create actions can establish mock→real mappings
    // before update/pay are attempted.
    List<String> pending = List<String>.from(offlineQueue);
    for (int pass = 0; pass < 3; pass++) {
      if (pending.isEmpty) break;
      final List<String> nextPending = [];

      // Process create/submit first, then others in each pass.
      final decoded = pending.map((t) {
        try {
          return jsonDecode(t);
        } catch (_) {
          return null;
        }
      }).toList();
      final ordered = <Map<String, dynamic>>[];
      for (final d in decoded) {
        if (d is Map<String, dynamic>) ordered.add(d);
      }
      ordered.sort((a, b) {
        int rank(dynamic action) {
          final s = action?.toString();
          if (s == 'create' || s == 'submit') return 0;
          if (s == 'update') return 1;
          if (s == 'pay') return 2;
          return 3;
        }

        return rank(a['action']).compareTo(rank(b['action']));
      });

      _d('[OFFLINE SYNC] pass=${pass + 1} pending=${pending.length}');

      for (final task in ordered) {
        // Keep original raw json for pending list if needed
        final taskJson = jsonEncode(task);
        try {
          // Fallback for old format
          if (task['action'] == null) {
            final response = await http
                .post(
                  Uri.parse('$base/pos/order'),
                  headers: headers,
                  body: jsonEncode(task),
                )
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              syncedCount++;
              continue;
            }
            nextPending.add(taskJson);
            continue;
          }

          final action = task['action']?.toString();
          final Map<String, dynamic> payload = Map<String, dynamic>.from(
            task['payload'] ?? const {},
          );

          final rawMockId = task['mock_id'];
          final int mockId = rawMockId is int
              ? rawMockId
              : (int.tryParse(rawMockId?.toString() ?? '') ?? 0);

          final int targetId = (mockId < 0 && mockToRealId.containsKey(mockId))
              ? mockToRealId[mockId]!
              : mockId;

          // If we can't map a mock id yet, defer this task to the next pass.
          if ((action == 'update' || action == 'pay') &&
              targetId < 0 &&
              mockId < 0 &&
              !mockToRealId.containsKey(mockId)) {
            nextPending.add(taskJson);
            continue;
          }

          if (action == 'create' || action == 'submit') {
            final response = await http
                .post(
                  Uri.parse('$base/pos/order'),
                  headers: headers,
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              final jsonResp = jsonDecode(response.body);
              if (jsonResp['status'] == 'success') {
                int? realId;
                try {
                  final data = jsonResp['data'];
                  if (data is Map) {
                    final cand = data['order_id'] ?? data['id'];
                    if (cand is int) realId = cand;
                    if (cand is String) realId = int.tryParse(cand);
                  }
                  realId ??= (jsonResp['order_id'] is int)
                      ? jsonResp['order_id']
                      : null;
                  realId ??= (jsonResp['id'] is int) ? jsonResp['id'] : null;
                } catch (_) {}

                if (action == 'create' && mockId < 0 && realId != null) {
                  mockToRealId[mockId] = realId;
                  _d('[OFFLINE SYNC] mapped mockId=$mockId -> realId=$realId');
                  await _remapCachedOpenTicketMockId(
                    mockId: mockId,
                    realId: realId,
                    jsonResp: Map<String, dynamic>.from(jsonResp as Map),
                  );
                }

                // If this was an offline paid submit, replace the local "Unsynced" mock receipt
                // with the real backend receipt data so the UI becomes consistent.
                if (action == 'submit' && mockId < 0) {
                  try {
                    final data = jsonResp['data'];
                    await _removeFromCacheList(
                      'cached_receipt_history',
                      mockId,
                    );
                    if (data is Map<String, dynamic>) {
                      await _updateCacheList('cached_receipt_history', data);
                    } else if (data is Map) {
                      await _updateCacheList(
                        'cached_receipt_history',
                        Map<String, dynamic>.from(data),
                      );
                    }
                  } catch (_) {}
                }

                syncedCount++;
                continue;
              }
            }
            nextPending.add(taskJson);
            continue;
          }

          if (action == 'update') {
            final response = await http
                .post(
                  Uri.parse('$base/pos/order/$targetId/update'),
                  headers: headers,
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              syncedCount++;
              continue;
            }
            nextPending.add(taskJson);
            continue;
          }

          if (action == 'pay') {
            final response = await http
                .post(
                  Uri.parse('$base/pos/order/$targetId/pay'),
                  headers: headers,
                  body: jsonEncode(payload),
                )
                .timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              syncedCount++;
              continue;
            }
            nextPending.add(taskJson);
            continue;
          }

          // Unknown action — keep it
          nextPending.add(taskJson);
        } catch (_) {
          nextPending.add(taskJson);
        }
      }

      // De-dupe pending tasks for next pass
      pending = nextPending.toSet().toList();
    }

    await prefs.setStringList('offline_orders', pending);
    return syncedCount;
  }

  // ---------------------------------------------------------------------------
  // CATALOG MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> fetchToppings({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_toppings');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/toppings');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = jsonResp['data'];
          await prefs.setString('cached_toppings', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load toppings');
    } catch (e) {
      final cachedStr = prefs.getString('cached_toppings');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
      return [];
    }
  }

  Future<dynamic> addTopping(String name, double extraPrice) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/toppings');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'extra_price': extraPrice}),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        final data = jsonResp['data'];
        await _updateCacheList('cached_toppings', data);
        return data;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to add topping');
    } catch (e) {
      throw Exception('Network error: Cannot add topping');
    }
  }

  Future<void> deleteTopping(int id) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/toppings/$id');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 5));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode != 200 || jsonResp['status'] != 'success') {
        throw Exception(jsonResp['message'] ?? 'Failed to delete topping');
      }
      await _removeFromCacheList('cached_toppings', id);
    } catch (e) {
      throw Exception('Network error: Cannot delete topping');
    }
  }

  Future<List<dynamic>> fetchCategories({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_categories');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/categories');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = jsonResp['data'];
          await prefs.setString('cached_categories', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      final cachedStr = prefs.getString('cached_categories');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
      return [];
    }
  }

  Future<dynamic> saveCategory({
    int? id,
    required String name,
    required bool showInApp,
  }) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/categories');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'name': name,
              'pos_show_in_app': showInApp,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        final data = jsonResp['data'];
        await _updateCacheList('cached_categories', data);
        return data;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to save category');
    } catch (e) {
      throw Exception('Network error: Cannot save category');
    }
  }

  Future<void> deleteCategory(int id) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/categories/$id');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 5));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode != 200 || jsonResp['status'] != 'success') {
        throw Exception(jsonResp['message'] ?? 'Failed to delete category');
      }
      await _removeFromCacheList('cached_categories', id);
    } catch (e) {
      throw Exception('Network error: Cannot delete category');
    }
  }

  // Customers
  Future<List<dynamic>> fetchCustomers({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_customers');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/customers');
      final response = await http
          .get(url, headers: await _authHeaders())
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = jsonResp['data'];
          await prefs.setString('cached_customers', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load customers');
    } catch (e) {
      final cachedStr = prefs.getString('cached_customers');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
      return [];
    }
  }

  Future<dynamic> saveCustomer({
    int? id,
    required String name,
    String? phone,
    String? email,
    String? dateOfBirth,
    String? imageBase64,
  }) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/customers');
      final dob = dateOfBirth?.trim();
      final img = imageBase64?.trim();
      final response = await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode({
              'id': id,
              'name': name,
              'phone': phone,
              'email': email,
              // DOB field name can differ between Odoo implementations.
              // Send both keys for compatibility; backend can choose which to persist.
              if (dob != null && dob.isNotEmpty) 'date_of_birth': dob,
              if (dob != null && dob.isNotEmpty) 'birthdate': dob,
              if (img != null && img.isNotEmpty) 'image_base64': img,
            }),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        final data = jsonResp['data'];
        await _updateCacheList('cached_customers', data);
        return data;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to save customer');
    } catch (e) {
      throw Exception('Network error: Cannot save customer');
    }
  }

  Future<dynamic> saveProduct({
    int? id,
    required String name,
    required double listPrice,
    int? categoryId,
    List<int>? toppingIds,
    bool blockSelfOrder = false,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/products');
    final bodyData = <String, dynamic>{
      'name': name,
      'list_price': listPrice,
      'block_self_order': blockSelfOrder,
    };
    if (id != null) bodyData['id'] = id;
    if (categoryId != null) bodyData['categ_id'] = categoryId;
    if (toppingIds != null) {
      bodyData['topping_ids'] = toppingIds;
      bodyData['pos_topping_ids'] = toppingIds;
    }

    try {
      _d('==============================');
      _d('[API CALL] POST $url');
      _d('[API LOAD] $bodyData');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyData),
          )
          .timeout(const Duration(seconds: 5));

      _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
      _d('[API BODY] ${response.body}');
      _d('==============================');

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        final data = jsonResp['data'];
        await _updateCacheList('cached_products', data);
        return data;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to save product');
    } on SocketException catch (e) {
      throw Exception('Network error: Cannot save product ($e)');
    } on http.ClientException catch (e) {
      throw Exception('Network error: Cannot save product ($e)');
    } on FormatException catch (_) {
      throw Exception('Invalid response from server while saving product');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('Cannot save product: $e');
    }
  }

  Future<void> deleteProduct(int id) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/products/$id');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 5));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode != 200 || jsonResp['status'] != 'success') {
        throw Exception(jsonResp['message'] ?? 'Failed to delete product');
      }
      await _removeFromCacheList('cached_products', id);
    } catch (e) {
      throw Exception('Network error: Cannot delete product');
    }
  }

  Future<List<dynamic>> fetchCombos({bool forceRefresh = false}) async {
    // Combos are hidden per user request
    return [];
    /*
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_combos');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/combos');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = jsonResp['data'];
          await prefs.setString('cached_combos', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load combos');
    } catch (e) {
      final cachedStr = prefs.getString('cached_combos');
      if (cachedStr != null) {
        return jsonDecode(cachedStr);
      }
      throw Exception('Network error: Cannot fetch combos');
    }
    */
  }

  Future<dynamic> saveCombo({
    required String name,
    required double price,
    required List<Map<String, dynamic>> lines,
  }) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/combos');
      final bodyData = {'name': name, 'price': price, 'lines': lines};

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(bodyData),
          )
          .timeout(const Duration(seconds: 5));

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        final data = jsonResp['data'];
        await _updateCacheList('cached_combos', data);
        return data;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to save combo');
    } catch (e) {
      throw Exception('Network error: Cannot save combo');
    }
  }

  Future<void> deleteCombo(int id) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/combos/$id');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 5));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode != 200 || jsonResp['status'] != 'success') {
        throw Exception(jsonResp['message'] ?? 'Failed to delete combo');
      }
      await _removeFromCacheList('cached_combos', id);
    } catch (e) {
      throw Exception('Network error: Cannot delete combo');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRankingTop50() async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/ranking/top50');
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 7));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final jsonResp = jsonDecode(resp.body);
      if (jsonResp is Map && jsonResp['status'] == 'success') {
        final raw = jsonResp['data'];
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      throw Exception(
        (jsonResp is Map ? jsonResp['message'] : null) ?? 'Bad response',
      );
    } catch (e) {
      throw Exception('Network error: Cannot load ranking ($e)');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerOrders(int partnerId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/my_orders?partner_id=$partnerId');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return List<Map<String, dynamic>>.from(jsonResp['data']);
        }
      }
      throw Exception('Failed to load customer orders');
    } catch (e) {
      throw Exception('Network error: Cannot fetch customer orders');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingSelfOrders() async {
    final base = await getBaseUrl();
    try {
      final branchId = await getCachedBranchId();
      final url = Uri.parse('$base/pos/self_orders/pending').replace(
        queryParameters: (branchId != null && branchId > 0)
            ? {'branch_id': '$branchId'}
            : null,
      );
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return List<Map<String, dynamic>>.from(jsonResp['data']);
        }
      }
      throw Exception('Failed to load pending self orders');
    } catch (e) {
      throw Exception('Network error: Cannot fetch pending self orders');
    }
  }

  Future<void> confirmSelfOrderTransfer(int orderId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/confirm_transfer');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 7));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        return;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to confirm transfer');
    } catch (e) {
      throw Exception('Cannot confirm transfer: $e');
    }
  }

  Future<void> rejectSelfOrder(int orderId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/reject');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 7));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        return;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to reject order');
    } catch (e) {
      throw Exception('Cannot reject order: $e');
    }
  }

  Future<void> notifySelfOrderReady(int orderId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/notify_ready');
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 7));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        return;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to notify customer');
    } catch (e) {
      throw Exception('Cannot notify customer: $e');
    }
  }

  Future<Map<String, dynamic>> uploadTransferProof({
    required int orderId,
    required String imagePath,
    int? partnerId,
  }) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/transfer_proof');
      final request = http.MultipartRequest('POST', url);
      if (partnerId != null) {
        request.fields['partner_id'] = partnerId.toString();
      }
      request.files.add(await http.MultipartFile.fromPath('proof', imagePath));

      final streamed = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final body = await streamed.stream.bytesToString();
      final jsonResp = jsonDecode(body);
      if (streamed.statusCode == 200 && jsonResp['status'] == 'success') {
        return Map<String, dynamic>.from(jsonResp['data']);
      }
      throw Exception(jsonResp['message'] ?? 'Failed to upload transfer proof');
    } catch (e) {
      throw Exception('Cannot upload transfer proof: $e');
    }
  }

  Future<Map<String, dynamic>> fetchSelfOrderConfig({
    int? branchId,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = branchId != null ? 'cached_self_order_config_$branchId' : 'cached_self_order_config';
    if (!forceRefresh) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedStr));
      }
    }
    final base = await getBaseUrl();
    try {
      final queryParams = branchId != null && branchId > 0 ? '?branch_id=$branchId' : '';
      final url = Uri.parse('$base/pos/self_order_config$queryParams');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = Map<String, dynamic>.from(jsonResp['data']);
          await prefs.setString(cacheKey, jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load self-order config');
    } catch (e) {
      final cachedStr = prefs.getString(cacheKey);
      if (cachedStr != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedStr));
      }
      return {};
    }
  }

  /// Fetches loyalty points configuration from the backend.
  /// Returns a map with:
  ///   - `points_ratio`      (double)  — spend amount per 1 point
  ///   - `min_points_redeem` (int)     — minimum points required to redeem
  ///   - `points_label`      (String)  — display name for points (e.g. "Points")
  Future<Map<String, dynamic>> fetchLoyaltyConfig({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final defaultData = {
      'points_ratio': 100.0,
      'min_points_redeem': 0,
      'points_label': 'Points',
    };
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_loyalty_config');
      if (cachedStr != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedStr));
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/loyalty_config');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = Map<String, dynamic>.from(jsonResp['data']);
          await prefs.setString('cached_loyalty_config', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load loyalty config');
    } catch (e) {
      final cachedStr = prefs.getString('cached_loyalty_config');
      if (cachedStr != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedStr));
      }
      return defaultData;
    }
  }

  Future<bool> hasBasicCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('cached_products');
  }

  /// Syncs all remote data into local cache.
  ///
  /// When [onProgress] is null, fetches run in **parallel** (faster) for
  /// manual sync (e.g. POS menu). When [onProgress] is set, steps run
  /// **sequentially** so the UI can show a determinate progress bar and labels.
  Future<void> syncAllData({
    void Function(String message, double progress)? onProgress,
  }) async {
    // Best-effort: if a POS identity is already set locally, try to register it.
    try {
      await registerPosDeviceIfPossible();
    } catch (_) {}

    if (onProgress == null) {
      try {
        await syncOfflineOrders();
      } catch (_) {}

      final futures = <Future>[
        fetchProducts(limit: 500, forceRefresh: true),
        fetchTables(forceRefresh: true),
        fetchPaymentMethods(forceRefresh: true),
        fetchToppings(forceRefresh: true),
        fetchCategories(forceRefresh: true),
        fetchCombos(forceRefresh: true),
        fetchOpenTickets(forceRefresh: true),
        fetchReceiptHistory(forceRefresh: true),
        fetchCustomers(forceRefresh: true),
        fetchSelfOrderConfig(forceRefresh: true),
        fetchLoyaltyConfig(forceRefresh: true),
      ];
      await Future.wait(futures);
      return;
    }

    final steps = <(String, Future<void> Function())>[
      (
        'Syncing offline orders…',
        () async {
          try {
            await syncOfflineOrders();
          } catch (_) {}
        },
      ),
      (
        'Loading products and prices…',
        () => fetchProducts(limit: 500, forceRefresh: true),
      ),
      ('Loading tables…', () => fetchTables(forceRefresh: true)),
      (
        'Loading payment methods…',
        () => fetchPaymentMethods(forceRefresh: true),
      ),
      ('Loading toppings…', () => fetchToppings(forceRefresh: true)),
      ('Loading categories…', () => fetchCategories(forceRefresh: true)),
      ('Loading combos…', () => fetchCombos(forceRefresh: true)),
      ('Loading open tickets…', () => fetchOpenTickets(forceRefresh: true)),
      (
        'Loading receipt history…',
        () => fetchReceiptHistory(forceRefresh: true),
      ),
      ('Loading customers…', () => fetchCustomers(forceRefresh: true)),
      (
        'Loading self-order settings…',
        () => fetchSelfOrderConfig(forceRefresh: true),
      ),
      (
        'Loading loyalty settings…',
        () => fetchLoyaltyConfig(forceRefresh: true),
      ),
    ];

    for (var i = 0; i < steps.length; i++) {
      onProgress(steps[i].$1, i / steps.length);
      await steps[i].$2();
    }
    onProgress('All data ready', 1.0);
  }

  // ---------------------------------------------------------------------------
  // POS DEVICE / POS NAME REGISTRATION (AUDIT)
  // ---------------------------------------------------------------------------

  static const String _posNamePrefsKey = 'cached_pos_name';
  static const String _branchIdPrefsKey = 'cached_branch_id';
  static const String _branchNamePrefsKey = 'cached_branch_name';
  static const String _customerBranchIdPrefsKey = 'cached_customer_branch_id';
  static const String _customerBranchNamePrefsKey =
      'cached_customer_branch_name';
  static const String _pendingDeviceRegPrefsKey =
      'pending_pos_device_registration';
  static const String _posIdentityPromptSessionKey =
      'pos_identity_prompt_session';

  Future<String?> getCachedSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString('cached_user_session')?.trim();
    if (sid == null || sid.isEmpty) return null;
    return sid;
  }

  Future<void> clearPosIdentityRequiredFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_posIdentityPromptSessionKey);
  }

  /// Returns true only for the session created by the most recent cashier login,
  /// so we can prompt POS name on login but not on app resume.
  Future<bool> shouldPromptPosIdentityForThisSession() async {
    final prefs = await SharedPreferences.getInstance();
    final requiredSid = prefs.getString(_posIdentityPromptSessionKey)?.trim();
    if (requiredSid == null || requiredSid.isEmpty) return false;
    final currentSid = await getCachedSessionId();
    return currentSid != null &&
        currentSid.isNotEmpty &&
        currentSid == requiredSid;
  }

  Future<String?> getCachedPosName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_posNamePrefsKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setCachedPosName(String posName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_posNamePrefsKey, posName.trim());
  }

  Future<int?> getCachedBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_branchIdPrefsKey);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<String?> getCachedBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_branchNamePrefsKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setCachedBranch({
    int? branchId,
    required String branchName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (branchId != null && branchId > 0) {
      await prefs.setInt(_branchIdPrefsKey, branchId);
    } else {
      await prefs.remove(_branchIdPrefsKey);
    }
    await prefs.setString(_branchNamePrefsKey, branchName.trim());
  }

  Future<void> clearCachedBranch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_branchIdPrefsKey);
    await prefs.remove(_branchNamePrefsKey);
  }

  Future<int?> getCachedCustomerBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_customerBranchIdPrefsKey);
    if (v == null || v <= 0) return null;
    return v;
  }

  Future<String?> getCachedCustomerBranchName() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_customerBranchNamePrefsKey)?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setCachedCustomerBranch({
    required int branchId,
    required String branchName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_customerBranchIdPrefsKey, branchId);
    await prefs.setString(_customerBranchNamePrefsKey, branchName.trim());
  }

  /// Fetch available branches (admin-defined) for this user session.
  /// Backend: GET `/api/pos/branches`
  Future<List<Map<String, dynamic>>> fetchBranches() async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/branches');
    final headers = await _authHeaders(json: true);

    final resp = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load branches (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map || decoded['status']?.toString() != 'success') {
      throw Exception('Failed to load branches');
    }
    final data = decoded['data'];
    final list = data is List
        ? data
        : (data is Map && data['branches'] is List)
        ? data['branches'] as List
        : const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Public branch list (used before login, ex: cashier registration).
  /// Backend: GET `/api/pos/branches/public`
  Future<List<Map<String, dynamic>>> fetchBranchesPublic() async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/branches/public');
    final resp = await http
        .get(url, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Failed to load branches (${resp.statusCode})');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map || decoded['status']?.toString() != 'success') {
      throw Exception('Failed to load branches');
    }
    final data = decoded['data'];
    final list = data is List
        ? data
        : (data is Map && data['branches'] is List)
        ? data['branches'] as List
        : const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> _collectDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    final now = DateTime.now().toUtc().toIso8601String();

    if (kIsWeb) {
      return {
        'platform': 'web',
        'timestamp_utc': now,
        'device_name': 'Web',
        'device_id': 'web',
        'model': 'Web',
        'manufacturer': 'Web',
        'brand': 'Web',
      };
    }

    try {
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        final deviceName = _androidDeviceName(
          manufacturer: a.manufacturer,
          brand: a.brand,
          model: a.model,
          device: a.device,
          product: a.product,
        );
        return {
          'platform': 'android',
          'timestamp_utc': now,
          'device_name': deviceName,
          'manufacturer': a.manufacturer,
          'brand': a.brand,
          'model': a.model,
          'device': a.device,
          'product': a.product,
          'sdk_int': a.version.sdkInt,
          // Prefer a stable identifier if available; backend should treat as "best effort"
          'device_id': a.id,
        };
      }
      if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        final deviceName = _iosDeviceName(i.utsname.machine, i.model);
        return {
          'platform': 'ios',
          'timestamp_utc': now,
          'device_name': deviceName,
          'name': i.name,
          'model': i.model,
          'localized_model': i.localizedModel,
          'system_name': i.systemName,
          'system_version': i.systemVersion,
          'machine': i.utsname.machine,
          'device_id': i.identifierForVendor,
          'manufacturer': 'Apple',
          'brand': 'Apple',
        };
      }
      if (Platform.isMacOS) {
        final m = await plugin.macOsInfo;
        return {
          'platform': 'macos',
          'timestamp_utc': now,
          'device_name': m.model.isNotEmpty ? 'macOS ${m.model}' : 'macOS',
          'model': m.model,
          'computer_name': m.computerName,
          'os_release': m.osRelease,
          'kernel_version': m.kernelVersion,
          'device_id': m.systemGUID,
          'manufacturer': 'Apple',
          'brand': 'Apple',
        };
      }
      if (Platform.isWindows) {
        final w = await plugin.windowsInfo;
        return {
          'platform': 'windows',
          'timestamp_utc': now,
          'device_name': w.computerName.isNotEmpty
              ? 'Windows ${w.computerName}'
              : 'Windows',
          'computer_name': w.computerName,
          'product_name': w.productName,
          'build_number': w.buildNumber,
          'device_id': w.deviceId,
          'model': w.productName.isNotEmpty ? w.productName : 'Windows',
          'manufacturer': 'Microsoft',
          'brand': 'Microsoft',
        };
      }
      if (Platform.isLinux) {
        final l = await plugin.linuxInfo;
        return {
          'platform': 'linux',
          'timestamp_utc': now,
          'device_name': l.prettyName.isNotEmpty ? l.prettyName : 'Linux',
          'name': l.name,
          'version': l.version,
          'pretty_name': l.prettyName,
          'machine_id': l.machineId,
          'device_id': l.machineId,
          'model': l.prettyName.isNotEmpty ? l.prettyName : 'Linux',
          'manufacturer': 'Linux',
          'brand': 'Linux',
        };
      }
    } catch (e) {
      developer.log('DeviceInfo collection error: $e', name: 'ApiService');
      // fallthrough to unknown
    }

    // Fallback: use dart:io Platform info when device_info_plus fails
    String? os;
    String? osVer;
    try {
      os = Platform.operatingSystem;
      osVer = Platform.operatingSystemVersion;
    } catch (_) {}
    final plat = os ?? 'unknown';
    final ver = osVer ?? '';
    return {
      'platform': plat,
      'timestamp_utc': now,
      'device_name': ver.isNotEmpty ? '$plat $ver' : plat,
      'device_id': 'unknown',
      'model': ver.isNotEmpty ? ver : plat,
      'manufacturer': plat == 'android'
          ? 'Generic'
          : plat == 'ios'
          ? 'Apple'
          : 'unknown',
      'brand': plat == 'android'
          ? 'Generic'
          : plat == 'ios'
          ? 'Apple'
          : 'unknown',
    };
  }

  String _androidDeviceName({
    required String manufacturer,
    required String brand,
    required String model,
    required String device,
    required String product,
  }) {
    final maker = manufacturer.trim().isNotEmpty
        ? manufacturer.trim()
        : brand.trim();
    final code = model.trim();
    final normalizedCode = code.toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
    final normalizedDevice = device.toUpperCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );
    final normalizedProduct = product.toUpperCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );
    final lookupKeys = {normalizedCode, normalizedDevice, normalizedProduct};
    for (final entry in _androidModelNames.entries) {
      if (lookupKeys.contains(entry.key)) {
        return 'Android ${entry.value}';
      }
    }
    final cleanMaker = _cleanDevicePart(maker);
    final cleanModel = _cleanDevicePart(code);
    if (cleanMaker.isEmpty && cleanModel.isEmpty) return 'Android';
    if (cleanMaker.isEmpty) return 'Android $cleanModel';
    if (cleanModel.isEmpty) return 'Android $cleanMaker';
    if (cleanModel.toLowerCase().startsWith(cleanMaker.toLowerCase())) {
      return 'Android $cleanModel';
    }
    return 'Android $cleanMaker $cleanModel';
  }

  String _iosDeviceName(String machine, String fallbackModel) {
    final code = machine.trim();
    final mapped = _iosMachineNames[code];
    if (mapped != null) return 'iOS $mapped';
    final fallback = fallbackModel.trim().isNotEmpty
        ? fallbackModel.trim()
        : 'iPhone';
    return 'iOS $fallback';
  }

  String _cleanDevicePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\bandroid\b', caseSensitive: false), '')
        .trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .split(' ')
        .map(
          (part) =>
              part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  static const Map<String, String> _iosMachineNames = {
    'iPhone10,3': 'iPhone X',
    'iPhone10,6': 'iPhone X',
    'iPhone11,2': 'iPhone XS',
    'iPhone11,4': 'iPhone XS Max',
    'iPhone11,6': 'iPhone XS Max',
    'iPhone11,8': 'iPhone XR',
    'iPhone12,1': 'iPhone 11',
    'iPhone12,3': 'iPhone 11 Pro',
    'iPhone12,5': 'iPhone 11 Pro Max',
    'iPhone12,8': 'iPhone SE 2',
    'iPhone13,1': 'iPhone 12 mini',
    'iPhone13,2': 'iPhone 12',
    'iPhone13,3': 'iPhone 12 Pro',
    'iPhone13,4': 'iPhone 12 Pro Max',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,6': 'iPhone SE 3',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
  };

  static const Map<String, String> _androidModelNames = {
    'SMG991B': 'Samsung Galaxy S21',
    'SMG991U': 'Samsung Galaxy S21',
    'SMG991U1': 'Samsung Galaxy S21',
    'SMG991W': 'Samsung Galaxy S21',
    'SMG991N': 'Samsung Galaxy S21',
    'SMG996B': 'Samsung Galaxy S21+',
    'SMG996U': 'Samsung Galaxy S21+',
    'SMG996U1': 'Samsung Galaxy S21+',
    'SMG996W': 'Samsung Galaxy S21+',
    'SMG996N': 'Samsung Galaxy S21+',
    'SMG998B': 'Samsung Galaxy S21 Ultra',
    'SMG998U': 'Samsung Galaxy S21 Ultra',
    'SMG998U1': 'Samsung Galaxy S21 Ultra',
    'SMG998W': 'Samsung Galaxy S21 Ultra',
    'SMG998N': 'Samsung Galaxy S21 Ultra',
    '2201123G': 'Xiaomi 12',
    '2201123C': 'Xiaomi 12',
    '2201122G': 'Xiaomi 12 Pro',
    '2201122C': 'Xiaomi 12 Pro',
    '2206123SC': 'Xiaomi 12S',
    '2206122SC': 'Xiaomi 12S Pro',
    '2203121C': 'Xiaomi 12S Ultra',
    '22071212AG': 'Xiaomi 12T',
    '22081212UG': 'Xiaomi 12T Pro',
  };

  /// Exposed for FCM token registration (best-effort).
  Future<Map<String, dynamic>> getDeviceInfoForAudit() => _collectDeviceInfo();

  /// Register POS + device details to backend for auditing.
  ///
  /// Backend endpoint (to implement in Odoo): POST `/api/pos/device/register`
  /// This call is best-effort and should never block the cashier flow.
  Future<void> registerPosDevice({
    required int userId,
    required String cashierName,
    required String posName,
    int? branchId,
    String? branchName,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/device/register');
    final device = await _collectDeviceInfo();
    final payload = <String, dynamic>{
      'user_id': userId,
      'cashier_name': cashierName,
      'pos_name': posName.trim(),
      if (branchId != null && branchId > 0) 'branch_id': branchId,
      if ((branchName ?? '').trim().isNotEmpty)
        'branch_name': branchName!.trim(),
      'device': device,
    };

    final headers = await _authHeaders(json: true);
    try {
      final resp = await http
          .post(url, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 6));

      final body = resp.body;
      Map<String, dynamic>? jsonResp;
      try {
        jsonResp = Map<String, dynamic>.from(jsonDecode(body));
      } catch (_) {}

      if (resp.statusCode == 200 &&
          (jsonResp?['status']?.toString() == 'success')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingDeviceRegPrefsKey);
        return;
      }

      // save for retry
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingDeviceRegPrefsKey, jsonEncode(payload));
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingDeviceRegPrefsKey, jsonEncode(payload));
    }
  }

  /// If the device registration previously failed, retry it.
  Future<void> registerPosDeviceIfPossible() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingDeviceRegPrefsKey);
    if (pending == null || pending.isEmpty) return;

    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/device/register');
    final headers = await _authHeaders(json: true);

    try {
      final resp = await http
          .post(url, headers: headers, body: pending)
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final jsonResp = jsonDecode(resp.body);
        if (jsonResp is Map && jsonResp['status'] == 'success') {
          await prefs.remove(_pendingDeviceRegPrefsKey);
        }
      }
    } catch (_) {
      // keep pending for next time
    }
  }

  // ---------------------------------------------------------------------------
  // FCM TOKEN REGISTRATION
  // ---------------------------------------------------------------------------

  Future<void> registerFcmToken({
    required int userId,
    required String role,
    required String token,
    required Map<String, dynamic> device,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/fcm/register');
    final payload = {
      'user_id': userId,
      'role': role,
      'token': token,
      'device': device,
    };

    try {
      await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // ignore; token will re-register on next launch / refresh
    }
  }

  /// Deregisters the FCM token on the backend when a customer disables
  /// push notifications. This prevents the server from sending pushes to a
  /// token that is about to be (or has already been) deleted on-device.
  Future<void> deregisterFcmToken({required int userId}) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/fcm/deregister');
    try {
      final response = await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 6));
      _d('[FCM DEREGISTER] user_id=$userId status=${response.statusCode}');
    } catch (e) {
      _d('[FCM DEREGISTER] failed (non-critical): $e');
      // Non-critical: Firebase deleteToken() already prevents delivery;
      // backend will auto-clean on next UNREGISTERED error (Option D).
    }
  }

  Future<void> saveSelectedFavoritePlace(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_selected_favorite_place_id', id);
  }

  /// Paginated customer search - optimized for large datasets
  /// Uses server-side search with LIMIT and OFFSET
  Future<CustomerSearchResult> searchCustomersPaginated({
    required String query,
    required int limit,
    required int offset,
  }) async {
    final base = await getBaseUrl();
    try {
      final queryParams = <String, String>{
        'q': query,
        'limit': '$limit',
        'offset': '$offset',
      };

      final url = Uri.parse(
        '$base/pos/customers/search',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final data = jsonResponse['data'];
          final customers = List<Map<String, dynamic>>.from(
            data['customers'] ?? [],
          );
          final hasMore = data['has_more'] == true || data['hasMore'] == true;
          final totalCount = data['total_count'] ?? data['totalCount'] ?? 0;

          return CustomerSearchResult(
            customers: customers,
            hasMore: hasMore,
            totalCount: totalCount,
          );
        }
      }
      throw Exception('Failed to search customers');
    } catch (e) {
      throw Exception('Failed to search customers: $e');
    }
  }

  Future<Map<String, dynamic>> validateCoupon(String code, {int? partnerId}) async {
    try {
      final base = await getBaseUrl();
      final response = await http.post(
        Uri.parse('$base/pos/validate_coupon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'coupon_code': code,
          if (partnerId != null) 'partner_id': partnerId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data['data'];
      }
      throw Exception(data['message'] ?? 'Failed to validate coupon');
    } catch (e) {
      throw Exception('Failed to validate coupon: $e');
    }
  }

  Future<Map<String, dynamic>> redeemVoucher(int partnerId, int productId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/customer/redeem_voucher');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'partner_id': partnerId, 'product_id': productId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to redeem voucher');
    } catch (e) {
      throw Exception('Failed to redeem voucher: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyVouchers(int partnerId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/customer/my_vouchers?partner_id=$partnerId');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(data['vouchers'] ?? []);
      }
      throw Exception(data['error'] ?? 'Failed to fetch vouchers');
    } catch (e) {
      throw Exception('Failed to fetch vouchers: $e');
    }
  }

  Future<Map<String, dynamic>> claimVoucher(String code) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/claim_voucher');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to claim voucher');
    } catch (e) {
      throw Exception('Failed to claim voucher: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Order Chat
  // ---------------------------------------------------------------------------

  /// Fetch all chat messages for an order.
  /// GET `/api/pos/order/<id>/chat`
  Future<Map<String, dynamic>> fetchOrderChat(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final sid = await getCachedSessionId() ?? '';
      final url = Uri.parse('$base/pos/order/$orderId/chat').replace(
        queryParameters: {
          if (userId > 0) 'user_id': '$userId',
          if (sid.isNotEmpty) 'session_id': sid,
        },
      );
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        return Map<String, dynamic>.from(json['data'] ?? {});
      }
      throw Exception(json['message'] ?? 'Failed to fetch chat');
    } catch (e) {
      throw Exception('Failed to fetch order chat: $e');
    }
  }

  /// Send a chat message for an order.
  /// POST `/api/pos/order/<id>/chat`
  Future<ChatMessage> sendOrderChatMessage(int orderId, String message) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final sid = await getCachedSessionId() ?? '';
      final url = Uri.parse('$base/pos/order/$orderId/chat').replace(
        queryParameters: {
          if (userId > 0) 'user_id': '$userId',
          if (sid.isNotEmpty) 'session_id': sid,
        },
      );
      final response = await http
          .post(
            url,
            headers: await _authHeaders(json: true),
            body: jsonEncode({'message': message}),
          )
          .timeout(const Duration(seconds: 10));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
      }
      throw Exception(json['message'] ?? 'Failed to send message');
    } catch (e) {
      throw Exception('Failed to send chat message: $e');
    }
  }

  /// Mark all incoming chat messages as read.
  /// POST `/api/pos/order/<id>/chat/read`
  Future<void> markOrderChatRead(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final sid = await getCachedSessionId() ?? '';
      final url = Uri.parse('$base/pos/order/$orderId/chat/read').replace(
        queryParameters: {
          if (userId > 0) 'user_id': '$userId',
          if (sid.isNotEmpty) 'session_id': sid,
        },
      );
      await http
          .post(url, headers: await _authHeaders(json: true), body: '{}')
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // best-effort
    }
  }

  /// Upload an image to the chat for an order.
  /// POST `/api/pos/order/<id>/chat/image` — multipart/form-data field "image", optional "caption".
  Future<ChatMessage> sendOrderChatImage(
    int orderId,
    String imagePath, {
    String caption = '',
  }) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final sid = await getCachedSessionId() ?? '';
      final url = Uri.parse('$base/pos/order/$orderId/chat/image').replace(
        queryParameters: {
          if (userId > 0) 'user_id': '$userId',
          if (sid.isNotEmpty) 'session_id': sid,
        },
      );
      final authHdrs = await _authHeaders(json: false);
      final request = http.MultipartRequest('POST', url);
      authHdrs.forEach((k, v) => request.headers[k] = v);
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));
      if (caption.isNotEmpty) request.fields['caption'] = caption;
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['status'] == 'success') {
        return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
      }
      throw Exception(json['message'] ?? 'Failed to upload image');
    } catch (e) {
      throw Exception('Failed to send chat image: $e');
    }
  }

  /// Fetch the unread message count for a chat badge.
  /// GET `/api/pos/order/<id>/chat/unread`
  Future<int> fetchOrderChatUnreadCount(int orderId) async {
    final base = await getBaseUrl();
    try {
      final user = await getCachedUser();
      final userId = (user != null && user['user_id'] != null)
          ? (user['user_id'] is int
                ? user['user_id'] as int
                : int.tryParse(user['user_id']?.toString() ?? '') ?? 0)
          : 0;
      final sid = await getCachedSessionId() ?? '';
      final url = Uri.parse('$base/pos/order/$orderId/chat/unread').replace(
        queryParameters: {
          if (userId > 0) 'user_id': '$userId',
          if (sid.isNotEmpty) 'session_id': sid,
        },
      );
      final response = await http
          .get(url, headers: await _authHeaders(json: true))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['status'] == 'success') {
          return (json['data']?['unread_count'] as num?)?.toInt() ?? 0;
        }
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }
}

/// Result class for paginated receipt fetch
class ReceiptHistoryResult {
  final List<Map<String, dynamic>> receipts;
  final bool hasMore;
  final int totalCount;

  const ReceiptHistoryResult({
    required this.receipts,
    required this.hasMore,
    this.totalCount = 0,
  });
}

/// Result class for paginated customer search
class CustomerSearchResult {
  final List<Map<String, dynamic>> customers;
  final bool hasMore;
  final int totalCount;

  const CustomerSearchResult({
    required this.customers,
    required this.hasMore,
    this.totalCount = 0,
  });
}
