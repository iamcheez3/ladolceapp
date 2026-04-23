import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
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


  /// Returns cached products instantly (null if no cache)
  Future<List<Product>?> getCachedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_products');
    if (cached == null) return null;
    final List<dynamic> data = jsonDecode(cached);
    return data.map((json) => Product.fromJson(json)).toList();
  }

  Future<List<Product>> fetchProducts({int limit = 50, int offset = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final base = await getBaseUrl();

    try {
      final url = Uri.parse('$base/products?limit=$limit&offset=$offset');
      print('==============================');
      print('[API CALL] GET $url');
      
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      print('[API RESP] GET $url | STATUS: ${response.statusCode}');
      print('[API BODY] ${response.body}');
      print('==============================');

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
      print('[API OFFLINE] Fetch products failed. Falling back to cache. Error: $e');
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

  Future<List<PosTable>> fetchTables() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<List<PaymentMethod>> fetchPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
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

  Future<List<OpenTicket>> fetchOpenTickets() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/open_tickets');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => OpenTicket.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load tickets');
    } catch (e) {
      throw Exception('Network error: Cannot fetch open tickets');
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceiptHistory() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/history');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          return List<Map<String, dynamic>>.from(jsonResponse['data']);
        }
      }
      throw Exception('Failed to load receipt history');
    } catch (e) {
      throw Exception('Network error: Cannot fetch receipt history');
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
      if (phone != null) 'phone': phone,
    };
    
    print('==============================');
    print('[API CALL] POST $url');
    print('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('[API RESP] POST $url | STATUS: ${response.statusCode}');
    print('[API BODY] ${response.body}');
    print('==============================');

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
      if (dbName != null) 'db': dbName,
      'login': normalizedLogin,
      'password': password,
    };

    print('==============================');
    print('[API CALL] POST $url');
    print('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    print('[API RESP] POST $url | STATUS: ${response.statusCode}');
    print('[API BODY] ${response.body}');
    print('==============================');

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

  Future<void> setPosPin(String pin) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/set_pin');
    final response = await http
        .post(
          url,
          headers: await _authHeaders(json: true),
          body: jsonEncode({'pin': pin}),
        )
        .timeout(const Duration(seconds: 6));

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode != 200 || jsonResponse['status'] != 'success') {
      throw Exception(jsonResponse['message'] ?? 'Failed to save PIN');
    }

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
      print('==============================');
      print('[API CALL] POST $url');
      print('[API LOAD] $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      print('[API RESP] POST $url | STATUS: ${response.statusCode}');
      print('[API BODY] ${response.body}');
      print('==============================');

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        return jsonResponse['data'];
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to submit order');
      }
    } catch (e) {
      print('[API OFFLINE] Order failed to submit. Saving to offline queue. Error: $e');
      await _queueOfflineOrder(payload);
      return {
        'offline': true,
        'order_id': 0,
        'order_reference': 'OFFLINE-${DateTime.now().millisecondsSinceEpoch}',
        'amount_total': 0.0,
        'state': 'draft'
      };
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
      if (name != null) 'name': name,
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
        return jsonResponse['data'];
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      await _queueOfflineOrder(payload);
      return {
        'offline': true,
        'order_id': 0,
        'order_reference': 'OFFLINE-${DateTime.now().millisecondsSinceEpoch}',
      };
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
      print('==============================');
      print('[API CALL] POST $url');
      print('[API LOAD] $payload');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      print('[API RESP] POST $url | STATUS: ${response.statusCode}');
      print('[API BODY] ${response.body}');
      print('==============================');

      final jsonResponse = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        return jsonResponse['data'];
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to update order');
      }
    } catch (e) {
      throw Exception('Failed to update order: $e');
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

    print('==============================');
    print('[API CALL] POST $url (PAY)');
    print('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 5));

    print('[API RESP] POST $url | STATUS: ${response.statusCode}');
    print('[API BODY] ${response.body}');
    print('==============================');

    final jsonResponse = jsonDecode(response.body);
    if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
      return jsonResponse['data'];
    } else {
      throw Exception(jsonResponse['message'] ?? 'Failed to pay order');
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

    print('==============================');
    print('[API CALL] POST $url (DELETE ORDER)');
    print('[API LOAD] $payload');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 5));

    print('[API RESP] POST $url | STATUS: ${response.statusCode}');
    print('[API BODY] ${response.body}');
    print('==============================');

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

  Future<void> _queueOfflineOrder(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineQueue = prefs.getStringList('offline_orders') ?? [];
    offlineQueue.add(jsonEncode(payload));
    await prefs.setStringList('offline_orders', offlineQueue);
  }

  Future<int> syncOfflineOrders() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> offlineQueue = prefs.getStringList('offline_orders') ?? [];
    
    if (offlineQueue.isEmpty) return 0;
    
    int syncedCount = 0;
    List<String> remainingQueue = [];
    final base = await getBaseUrl();
    final url = Uri.parse('$base/pos/order');

    for (String orderJson in offlineQueue) {
      try {
        final payload = jsonDecode(orderJson);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 4));
        
        if (response.statusCode == 200) {
          final jsonResp = jsonDecode(response.body);
          if (jsonResp['status'] == 'success') {
            syncedCount++;
            continue;
          }
        }
        remainingQueue.add(orderJson);
      } catch (e) {
        remainingQueue.add(orderJson);
      }
    }
    
    await prefs.setStringList('offline_orders', remainingQueue);
    return syncedCount;
  }

  // ---------------------------------------------------------------------------
  // CATALOG MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<List<dynamic>> fetchToppings() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/toppings');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return jsonResp['data'];
        }
      }
      throw Exception('Failed to load toppings');
    } catch (e) {
      throw Exception('Network error: Cannot fetch toppings');
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
        return jsonResp['data'];
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
    } catch (e) {
      throw Exception('Network error: Cannot delete topping');
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/categories');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return jsonResp['data'];
        }
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      throw Exception('Network error: Cannot fetch categories');
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
        return jsonResp['data'];
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
    } catch (e) {
      throw Exception('Network error: Cannot delete category');
    }
  }

  // Customers
  Future<List<dynamic>> fetchCustomers() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/customers');
      final response = await http.get(url, headers: await _authHeaders()).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return jsonResp['data'];
        }
      }
      throw Exception('Failed to load customers');
    } catch (e) {
      throw Exception('Network error: Cannot fetch customers');
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
        return jsonResp['data'];
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
      print('==============================');
      print('[API CALL] POST $url');
      print('[API LOAD] $bodyData');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyData),
      ).timeout(const Duration(seconds: 5));

      print('[API RESP] POST $url | STATUS: ${response.statusCode}');
      print('[API BODY] ${response.body}');
      print('==============================');

      final jsonResp = jsonDecode(response.body);
      if (response.statusCode == 200 && jsonResp['status'] == 'success') {
        return jsonResp['data'];
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
    } catch (e) {
      throw Exception('Network error: Cannot delete product');
    }
  }

  Future<List<dynamic>> fetchCombos() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/combos');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return jsonResp['data'];
        }
      }
      throw Exception('Failed to load combos');
    } catch (e) {
      throw Exception('Network error: Cannot fetch combos');
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
        return jsonResp['data'];
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

  Future<Map<String, dynamic>> fetchSelfOrderConfig() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/self_order_config');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return Map<String, dynamic>.from(jsonResp['data']);
        }
      }
      throw Exception('Failed to load self-order config');
    } catch (e) {
      throw Exception('Network error: Cannot fetch self-order config');
    }
  }

  /// Fetches loyalty points configuration from the backend.
  /// Returns a map with:
  ///   - `points_ratio`      (double)  — spend amount per 1 point
  ///   - `min_points_redeem` (int)     — minimum points required to redeem
  ///   - `points_label`      (String)  — display name for points (e.g. "Points")
  Future<Map<String, dynamic>> fetchLoyaltyConfig() async {
    final base = await getBaseUrl();
    try {
      final url = Uri.parse('$base/pos/loyalty_config');
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final jsonResp = jsonDecode(response.body);
        if (jsonResp['status'] == 'success') {
          return Map<String, dynamic>.from(jsonResp['data']);
        }
      }
      throw Exception('Failed to load loyalty config');
    } catch (e) {
      // Return safe defaults so the app never crashes when offline
      return {
        'points_ratio': 100.0,
        'min_points_redeem': 0,
        'points_label': 'Points',
      };
    }
  }
}