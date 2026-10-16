import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ladolce/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product, category and combo saves/deletes are behind @require_session()
/// on the server: they must carry the login (header, user_id, session_id).
void main() {
  late List<http.Request> sent;
  late http.Response Function(http.Request) answer;

  setUp(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://pos.test/api');
    SharedPreferences.setMockInitialValues({
      'dev_base_url_override': 'https://pos.test/api',
      'cached_user_data': jsonEncode({'user_id': 7, 'role': 'admin'}),
      'cached_user_session': 'sid-123',
    });
    sent = [];
    answer = (_) => http.Response(
      jsonEncode({
        'status': 'success',
        'data': {'id': 5, 'name': 'Aerocano'},
      }),
      200,
    );
  });

  Future<T> withServer<T>(Future<T> Function() body) => http.runWithClient(
    body,
    () => MockClient((request) async {
      sent.add(request);
      return answer(request);
    }),
  );

  void expectSession(http.Request r) {
    expect(r.headers['X-Openerp-Session-Id'], 'sid-123');
    if (r.method == 'POST') {
      final body = jsonDecode(r.body) as Map;
      expect(body['user_id'], '7');
      expect(body['session_id'], 'sid-123');
    } else {
      expect(r.url.queryParameters['user_id'], '7');
      expect(r.url.queryParameters['session_id'], 'sid-123');
    }
  }

  test('saving a product sends the session', () async {
    await withServer(
      () => ApiService().saveProduct(id: 5, name: 'Aerocano', listPrice: 35000),
    );
    expect(sent.single.url.path, '/api/pos/products');
    expectSession(sent.single);
  });

  test('saving a category and a combo send the session', () async {
    await withServer(
      () => ApiService().saveCategory(name: 'Coffee', showInApp: true),
    );
    await withServer(
      () => ApiService().saveCombo(name: 'Set', price: 50000, lines: const []),
    );
    expect(sent.map((r) => r.url.path), [
      '/api/pos/categories',
      '/api/pos/combos',
    ]);
    sent.forEach(expectSession);
  });

  test('deleting a product, category or combo sends the session', () async {
    await withServer(() => ApiService().deleteProduct(5));
    await withServer(() => ApiService().deleteCategory(3));
    await withServer(() => ApiService().deleteCombo(2));
    expect(sent.map((r) => r.url.path), [
      '/api/pos/products/5',
      '/api/pos/categories/3',
      '/api/pos/combos/2',
    ]);
    sent.forEach(expectSession);
  });

  test("a refusal shows the server's reason, not 'Network error'", () async {
    answer = (_) => http.Response(
      jsonEncode({
        'status': 'error',
        'message': 'Missing or invalid user session',
      }),
      401,
    );
    for (final call in <Future<void> Function()>[
      () => ApiService().saveCategory(name: 'Coffee', showInApp: true),
      () => ApiService().deleteProduct(5),
    ]) {
      await expectLater(
        withServer(call),
        throwsA(
          predicate((e) => '$e'.contains('Missing or invalid user session')),
        ),
      );
    }
  });
}
