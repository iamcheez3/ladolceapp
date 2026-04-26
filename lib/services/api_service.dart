import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/table.dart';
import '../models/payment_method.dart';
import '../models/ticket.dart';

class ApiService {
  /// Key used to store the dev IP override in SharedPreferences.
  static const String devBaseUrlKey = 'dev_base_url_override';
  static const String devDbNameKey = 'dev_db_name_override';

  String get baseUrl {
    // NOTE: baseUrl is synchronous; the dev override is loaded via
    // getBaseUrl() below for any code that can await. This getter is kept
    // for backward-compat with all existing synchronous call-sites.
    String envUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8069/api';
    if (Platform.isAndroid && envUrl.contains('localhost')) {
      return envUrl.replaceAll('localhost', '10.0.2.2');
    }
    return envUrl;
  }

  /// Async version that respects the dev IP override saved in prefs.
  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(devBaseUrlKey);
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return baseUrl;
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
    final contentMatch =
        RegExp(r'^/web/content/(\d+)(\?.*)?$').firstMatch(normalized);
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
    final idx = list.indexWhere(
      (e) => e is Map && (e)['id'] == mockId,
    );
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
    _d('[OFFLINE SYNC] remapped open ticket in cache: mockId=$mockId -> $realId');
  }

  /// Async variant that respects dev base URL override from SharedPreferences.
  Future<String> resolveMediaUrlAsync(String rawUrl) async {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) return '';
    final contentMatch =
        RegExp(r'^/web/content/(\d+)(\?.*)?$').firstMatch(normalized);
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
      'Cookie': 'session_id=$sessionId',
      'X-Openerp-Session-Id': sessionId,
    };
  }

  Future<Map<String, String>> _authHeaders({bool json = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('cached_user_session');
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['Cookie'] = 'session_id=$sessionId';
      headers['X-Openerp-Session-Id'] = sessionId;
    }
    return headers;
  }

  Future<void> _updateCacheList(String key, Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    // Always create list even if cache doesn't exist yet
    final list = cached != null ? List<dynamic>.from(jsonDecode(cached)) : <dynamic>[];
    final index = list.indexWhere((e) => e != null && e is Map && e['id'] == item['id']);
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

  Future<void> _markTableHasOpenOrder(int tableId, {required bool hasOpenOrder}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_tables');
    if (cached == null) return;

    try {
      final list = List<dynamic>.from(jsonDecode(cached));
      final idx = list.indexWhere((e) => e != null && e is Map && e['id'] == tableId);
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
  Future<List<Product>?> getCachedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_products');
    if (cached == null) return null;
    final List<dynamic> data = jsonDecode(cached);
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> fetchProducts({int limit = 50, int offset = 0, bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_products');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr);
        return data.map((json) => Product.fromJson(json)).toList();
      }
    }
    
    final base = await getBaseUrl();

    try {
      final url = Uri.parse('$base/products?limit=$limit&offset=$offset');
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
          await prefs.setString('cached_products', jsonEncode(data));
          return data.map((json) => Product.fromJson(json)).toList();
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load products from server');
        }
      } else {
        throw Exception('Failed to connect to Odoo Server (Code: ${response.statusCode})');
      }
    } catch (e) {
      _d('[API OFFLINE] Fetch products failed. Falling back to cache. Error: $e');
      final cachedProducts = prefs.getString('cached_products');
      if (cachedProducts != null) {
        final List<dynamic> data = jsonDecode(cachedProducts);
        return data.map((json) => Product.fromJson(json)).toList();
      }
      throw Exception('No internet connection and no offline cached products available.');
    }
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
      final url = Uri.parse('$base/pos/tables');
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

  Future<List<PaymentMethod>> fetchPaymentMethods({bool forceRefresh = false}) async {
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
            .map((e) => OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    }
    
    final base = await getBaseUrl();
    final prevOpenTickets = prefs.getString('cached_open_tickets');
    try {
      final url = Uri.parse('$base/pos/open_tickets');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'] as List<dynamic>;
          final merged = _mergeLocalDraftOpenTickets(data, prevOpenTickets);
          await prefs.setString('cached_open_tickets', jsonEncode(merged));
          return merged
              .map((e) =>
                  OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      throw Exception('Failed to load tickets');
    } catch (e) {
      final cachedStr = prefs.getString('cached_open_tickets');
      if (cachedStr != null) {
        final List<dynamic> data = jsonDecode(cachedStr) as List<dynamic>;
        return data
            .map((e) =>
                OpenTicket.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceiptHistory({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_receipt_history');
      if (cachedStr != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
      }
    }
    
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/history');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
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

  Future<Map<String, dynamic>> fetchOrderReceipt(int orderId) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/order/$orderId/receipt');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
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

  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String login,
    required String password,
    required String role,
    String? phone,
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/register');
    final Map<String, dynamic> payload = {
      'name': name,
      'login': login,
      'password': password,
      'role': role,
      'phone': ?phone,
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

  Future<Map<String, dynamic>> loginUser(String login, String password) async {
    final base = await getBaseUrl();
    final dbName = await getDatabaseName();
    final url = Uri.parse('$base/pos/login');
    final normalizedLogin = login.trim().toLowerCase();
    final Map<String, dynamic> payload = {
      'db': ?dbName,
      'login': normalizedLogin,
      'password': password,
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
      final data = jsonResponse['data'];
      final sessionId = jsonResponse['session_id'];
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_session', sessionId ?? '');
      await prefs.setString('cached_user_data', jsonEncode(data));
      
      return data;
    } else {
      throw Exception(jsonResponse['message'] ?? 'Login failed');
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

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_session');
    await prefs.remove('cached_user_data');
  }
  Future<void> setPosPin(String pin, int userId) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/set_pin');

    _d('==============================');
    _d('[SET PIN] POST $url');
    _d('[SET PIN] user_id: $userId | pin: $pin');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'}, // ← no session needed now
      body: jsonEncode({'pin': pin, 'user_id': userId}),
    ).timeout(const Duration(seconds: 6));

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
  }) async {
    final base = await getBaseUrl();
    final payload = {
      'user_id': userId,
      'partner_id': partnerId,
      'table_id': tableId,
      'payment_method_id': paymentMethodId,
      'payment_type': paymentType,
      'is_paid': isPaid,
      'lines': lines,
    };
    
    try {
      final url = Uri.parse('$base/pos/order');
      _d('==============================');
      _d('[API CALL] POST $url');
      _d('[API LOAD] $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      _d('[API RESP] POST $url | STATUS: ${response.statusCode}');
      _d('[API BODY] ${response.body}');
      _d('==============================');

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final data = jsonResponse['data'];
        await _updateCacheList('cached_receipt_history', data);
        return data;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to submit order');
      }
    } catch (e) {
      _d('[API OFFLINE] Order failed to submit. Saving to offline queue. Error: $e');
      final mockId = -DateTime.now().millisecondsSinceEpoch;
      await _queueOfflineOrder({
        'action': 'submit',
        'payload': payload,
        'mock_id': mockId
      });
      final now = DateTime.now();
      final mockReceipt = {
        'offline': true,
        'synced': false,
        'id': mockId,
        'name': 'OFFLINE-$mockId',
        'order_reference': 'OFFLINE-$mockId',
        'date_order': now.toIso8601String(),
        if (isPaid) 'date_paid': now.toIso8601String(),
        'payment_method': paymentMethodId != null ? 'Method #$paymentMethodId' : 'Offline',
        'amount_total': lines.fold<double>(0.0, (sum, line) => sum + (line['price_unit'] * line['qty'])),
        'state': isPaid ? 'paid' : 'draft'
      };
      await _updateCacheList('cached_receipt_history', mockReceipt);
      return mockReceipt;
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required int userId,
    int? tableId,
    int? customerId,
    String? name,
    required List<Map<String, dynamic>> lines,
  }) async {
    final base = await getBaseUrl();
    final payload = {
      'user_id': userId,
      'table_id': tableId,
      'partner_id': customerId,
      'name': ?name,
      'lines': lines,
    };

    try {
      final url = Uri.parse('$base/pos/order');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final data = jsonResponse['data'];
        final total = lines.fold<double>(0.0, (sum, line) => sum + ((line['price_unit'] as num).toDouble() * (line['qty'] as num).toInt()));
        final localTicket = {
            'id': data['order_id'],
            'name': data['order_reference'],
            'table_id': tableId,
            'table_name': tableId != null ? 'Table $tableId' : (name ?? 'Customer'),
            'amount_total': total,
            'state': 'draft',
            // Needed for Open Tickets duration badge (see OpenTicket.openedAt)
            'opened_at': DateTime.now().toUtc().toIso8601String(),
            'lines': lines.map((l) => {
                 'product_id': l['product_id'],
                 'product_name': 'Item',
                 'qty': l['qty'],
                 'price_unit': l['price_unit'],
                 'topping_ids': l['topping_ids'] ?? []
            }).toList()
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
         'mock_id': mockId
      });
      final total = lines.fold<double>(0.0, (sum, line) => sum + ((line['price_unit'] as num).toDouble() * (line['qty'] as num).toInt()));
      final mockTicket = {
         'id': mockId,
         'name': 'OFFLINE-MOCK', // Using static or mock name
         'table_id': tableId,
         'table_name': tableId != null ? 'Table $tableId' : (name ?? 'Customer'),
         'partner_id': customerId, // keeping for record
         'amount_total': total,
         'state': 'draft',
         // Needed for Open Tickets duration badge (see OpenTicket.openedAt)
         'opened_at': DateTime.now().toUtc().toIso8601String(),
         'lines': lines.map((l) => {
             'product_id': l['product_id'],
             'product_name': 'Item',
             'qty': l['qty'],
             'price_unit': l['price_unit'],
             'topping_ids': l['topping_ids'] ?? []
         }).toList()
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
  }) async {
    final base = await getBaseUrl();
    final payload = {
      'table_id': tableId,
      'partner_id': customerId,
      'lines': lines,
      if (replaceAll) 'replace_all': true,
    };

    try {
      final url = Uri.parse('$base/pos/order/$orderId/update');
      _d('==============================');
      _d('[API CALL] POST $url');
      _d('[API LOAD] $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

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
           final index = list.indexWhere((e) => e != null && e is Map && e['id'] == orderId);
           if (index >= 0) {
              // Ensure existing cached tickets always keep an opened_at timestamp
              // so the Open Tickets screen can show the live duration badge.
              if (list[index] is Map &&
                  (list[index]['opened_at'] == null ||
                      (list[index]['opened_at']?.toString().isEmpty ?? true))) {
                list[index]['opened_at'] = DateTime.now().toUtc().toIso8601String();
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
                        'topping_ids': l['topping_ids'] ?? []
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
                      'topping_ids': l['topping_ids'] ?? []
                    },
                  ),
                );
                list[index]['lines'] = existing;
              }
              // Always total the full ticket, not just this request's new lines
              // (append mode used to set amount_total to "latest lines only").
              list[index]['amount_total'] =
                  _sumCachedOpenTicketLinesAmount(list[index]['lines']);
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
         'mock_id': orderId
      });
      // Also fetch and update local mock ticket
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_open_tickets');
      if (cached != null) {
         final list = List<dynamic>.from(jsonDecode(cached));
         final index = list.indexWhere((e) => e != null && e is Map && e['id'] == orderId);
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
                      'topping_ids': l['topping_ids'] ?? []
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
                    'topping_ids': l['topping_ids'] ?? []
                  },
                ),
              );
              list[index]['lines'] = existing;
            }
            list[index]['amount_total'] =
                _sumCachedOpenTicketLinesAmount(list[index]['lines']);
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
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/order/$orderId/pay');
    final payload = {
      'payment_method_id': paymentMethodId,
    };

    _d('==============================');
    _d('[API CALL] POST $url (PAY)');
    _d('[API LOAD] $payload');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        final data = jsonResponse['data'];
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
         'mock_id': orderId
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
                : double.tryParse(t['amount_total']?.toString() ?? '') ?? amountTotal;
            dateOrder = (t['opened_at'] ?? t['date_order'] ?? dateOrder).toString();
          }
        }
      } catch (_) {}

      await _removeFromCacheList('cached_open_tickets', orderId);
      if (tableId != null) {
        await _markTableHasOpenOrder(tableId, hasOpenOrder: false);
      }
      final mockReceipt = {
         'offline': true,
         'synced': false,
         'id': orderId,
         'name': name,
         'order_reference': name,
         'date_order': dateOrder,
         'date_paid': DateTime.now().toIso8601String(),
         'payment_method': paymentMethodId != null ? 'Method #$paymentMethodId' : 'Offline',
         'state': 'paid',
         'amount_total': amountTotal,
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
    final payload = {
      'admin_pin': adminPin,
    };

    _d('==============================');
    _d('[API CALL] POST $url (DELETE ORDER)');
    _d('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 5));

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
    final payload = {'admin_pin': adminPin};

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 8));

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
        try { return jsonDecode(t); } catch (_) { return null; }
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
            final response = await http.post(
              Uri.parse('$base/pos/order'),
              headers: headers,
              body: jsonEncode(task),
            ).timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              syncedCount++;
              continue;
            }
            nextPending.add(taskJson);
            continue;
          }

          final action = task['action']?.toString();
          final Map<String, dynamic> payload =
              Map<String, dynamic>.from(task['payload'] ?? const {});

          final rawMockId = task['mock_id'];
          final int mockId = rawMockId is int
              ? rawMockId
              : (int.tryParse(rawMockId?.toString() ?? '') ?? 0);

          final int targetId =
              (mockId < 0 && mockToRealId.containsKey(mockId))
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
            final response = await http.post(
              Uri.parse('$base/pos/order'),
              headers: headers,
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 8));
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
                  realId ??=
                      (jsonResp['order_id'] is int) ? jsonResp['order_id'] : null;
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
                    await _removeFromCacheList('cached_receipt_history', mockId);
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
            final response = await http.post(
              Uri.parse('$base/pos/order/$targetId/update'),
              headers: headers,
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 8));
            if (response.statusCode == 200) {
              syncedCount++;
              continue;
            }
            nextPending.add(taskJson);
            continue;
          }

          if (action == 'pay') {
            final response = await http.post(
              Uri.parse('$base/pos/order/$targetId/pay'),
              headers: headers,
              body: jsonEncode(payload),
            ).timeout(const Duration(seconds: 8));
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'extra_price': extraPrice}),
      ).timeout(const Duration(seconds: 5));
      
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
      final response = await http.delete(url).timeout(const Duration(seconds: 5));
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id': id,
          'name': name,
          'pos_show_in_app': showInApp,
        }),
      ).timeout(const Duration(seconds: 5));
      
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
      final response = await http.delete(url).timeout(const Duration(seconds: 5));
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
      final response = await http.get(url, headers: await _authHeaders()).timeout(const Duration(seconds: 5));
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

  Future<dynamic> saveCustomer({int? id, required String name, String? phone, String? email}) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/customers');
      final response = await http.post(
        url,
        headers: await _authHeaders(json: true),
        body: jsonEncode({'id': id, 'name': name, 'phone': phone, 'email': email}),
      ).timeout(const Duration(seconds: 5));
      
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
  }) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/products');
    final bodyData = <String, dynamic>{
      'name': name,
      'list_price': listPrice,
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

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 5));

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
      final response = await http.delete(url).timeout(const Duration(seconds: 5));
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
      return [];
    }
  }

  Future<dynamic> saveCombo({
    required String name,
    required double price,
    required List<Map<String, dynamic>> lines,
  }) async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/combos');
      final bodyData = {
        'name': name,
        'price': price,
        'lines': lines,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 5));

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
      final response = await http.delete(url).timeout(const Duration(seconds: 5));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode != 200 || jsonResp['status'] != 'success') {
        throw Exception(jsonResp['message'] ?? 'Failed to delete combo');
      }
      await _removeFromCacheList('cached_combos', id);
    } catch (e) {
      throw Exception('Network error: Cannot delete combo');
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
      final url = Uri.parse('$base/pos/self_orders/pending');
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 7));
      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        return;
      }
      throw Exception(jsonResp['message'] ?? 'Failed to confirm transfer');
    } catch (e) {
      throw Exception('Cannot confirm transfer: $e');
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

      final streamed = await request.send().timeout(const Duration(seconds: 15));
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

  Future<Map<String, dynamic>> fetchSelfOrderConfig({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedStr = prefs.getString('cached_self_order_config');
      if (cachedStr != null) {
        return Map<String, dynamic>.from(jsonDecode(cachedStr));
      }
    }
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/self_order_config');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          final data = Map<String, dynamic>.from(jsonResp['data']);
          await prefs.setString('cached_self_order_config', jsonEncode(data));
          return data;
        }
      }
      throw Exception('Failed to load self-order config');
    } catch (e) {
      final cachedStr = prefs.getString('cached_self_order_config');
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
  Future<Map<String, dynamic>> fetchLoyaltyConfig({bool forceRefresh = false}) async {
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
        fetchLoyaltyConfig(forceRefresh: true)
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
      (
        'Loading tables…',
        () => fetchTables(forceRefresh: true),
      ),
      (
        'Loading payment methods…',
        () => fetchPaymentMethods(forceRefresh: true),
      ),
      (
        'Loading toppings…',
        () => fetchToppings(forceRefresh: true),
      ),
      (
        'Loading categories…',
        () => fetchCategories(forceRefresh: true),
      ),
      (
        'Loading combos…',
        () => fetchCombos(forceRefresh: true),
      ),
      (
        'Loading open tickets…',
        () => fetchOpenTickets(forceRefresh: true),
      ),
      (
        'Loading receipt history…',
        () => fetchReceiptHistory(forceRefresh: true),
      ),
      (
        'Loading customers…',
        () => fetchCustomers(forceRefresh: true),
      ),
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
}