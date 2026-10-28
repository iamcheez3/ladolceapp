// Layout survey of the customer self-order screen (customer app) at many
// screen sizes, against the fake backend in screen_size_screens_test.dart.
// Never fails on a layout issue; read the "LAYOUT|" lines.
//
// Besides the menu (home tab, top and scrolled), it drives the app into the
// other customer surfaces: the options sheet, the cart, the checkout sheet,
// the order history (with orders in every status), the order detail screen
// and the profile tab.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/screens/customer_self_order_screen.dart';

import 'screen_size_harness_test.dart';
import 'screen_size_screens_test.dart' as fx;

const _customerName = 'Souksavanh Phommachanh Vongsakda';

Map<String, dynamic> _order(int id, String state, String delivery) => {
      'id': 500 + id,
      'name': 'Self-Order LaDolce Main/000$id-2345',
      'amount_total': 12345000 + id,
      'date_order': DateTime.now()
          .subtract(Duration(minutes: id * 7))
          .toUtc()
          .toIso8601String(),
      'payment_method': 'BCEL OnePay QR (Bank transfer)',
      'state': state,
      'delivery_status': delivery,
      'customer': _customerName,
      'transfer_proof_url': '',
      'lines': [
        {'product_name': fx.longEn, 'product_name_lo': fx.longLo, 'qty': 2,
         'subtotal': 2468000},
        {'product_name': 'Latte', 'product_name_lo': 'ລາເຕ້', 'qty': 1,
         'subtotal': 35000},
      ],
    };

final _orders = [
  _order(1, 'draft', 'ready'),
  _order(2, 'draft', 'preparing'),
  _order(3, 'draft', 'on_the_way'),
  _order(4, 'waiting_transfer_review', 'none'),
  _order(5, 'cancelled', 'none'),
  _order(6, 'paid', 'none'),
];

final _customer = {
  'id': 7,
  'name': _customerName,
  'phone': '2055551234',
  'email': 'souksavanh@example.com',
  'client_id': 'CUST-000123-VTE',
  'date_of_birth': '1990-05-17',
  'reward_points': 1234567,
  'reward_rank': 12,
};

/// The shared fake backend plus the customer endpoints (orders, profile).
http.Client _backend() => MockClient((req) async {
      final p = req.url.path;
      Object? data;
      if (p.endsWith('/pos/my_orders')) {
        data = _orders;
      } else if (p.endsWith('/pos/customers') && req.method == 'GET') {
        data = [_customer];
      }
      if (data == null) {
        return http.Response.fromStream(await fx.fakeBackend().send(req));
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode({'status': 'success', 'data': data})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> _settle(WidgetTester t) async {
  for (final d in const [
    Duration(milliseconds: 100),
    Duration(milliseconds: 400),
    Duration(milliseconds: 600),
  ]) {
    await t.pump(d);
  }
}

Future<void> _tapNav(WidgetTester t, IconData icon) async {
  final f = find.descendant(
      of: find.byType(NavigationBar), matching: find.byIcon(icon));
  if (f.evaluate().isEmpty) return;
  await t.tap(f.first, warnIfMissed: false);
  await _settle(t);
}

/// Taps the "+" on the first two menu rows; an item that needs a choice
/// opens the options sheet first, whose add button is then pressed.
Future<void> _addTwoItems(WidgetTester t) async {
  for (var i = 0; i < 2; i++) {
    final add = find.byIcon(Icons.add_rounded);
    if (add.evaluate().length <= i) break;
    await t.ensureVisible(add.at(i));
    await t.pump();
    await t.tap(add.at(i), warnIfMissed: false);
    await _settle(t);
    final sheetAdd = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(FilledButton));
    if (sheetAdd.evaluate().isNotEmpty) {
      await t.tap(sheetAdd.last, warnIfMissed: false);
      await _settle(t);
    }
  }
  // Clear the "added to cart" snackbars so they do not cover the cart.
  for (final m in find.byType(ScaffoldMessenger).evaluate()) {
    final state = (m as StatefulElement).state;
    if (state is ScaffoldMessengerState) state.clearSnackBars();
  }
  await _settle(t);
}

Future<void> _openCart(WidgetTester t) async {
  await _addTwoItems(t);
  await _tapNav(t, Icons.shopping_bag_outlined);
}

Future<void> _openOptions(WidgetTester t, String loc) async {
  final name = find.text(loc == 'lo' ? 'ລາເຕ້' : 'Latte');
  if (name.evaluate().isEmpty) return;
  await t.ensureVisible(name.first);
  await t.pump();
  await t.tap(name.first, warnIfMissed: false);
  await _settle(t);
}

Future<void> _openCheckout(WidgetTester t) async {
  await _openCart(t);
  final checkout = find.byType(FilledButton);
  if (checkout.evaluate().isEmpty) return;
  await t.tap(checkout.last, warnIfMissed: false);
  await _settle(t);
  await fx.scrollAll(t);
}

Future<void> _openHistory(WidgetTester t) =>
    _tapNav(t, Icons.receipt_long_outlined);

Future<void> _openDetail(WidgetTester t) async {
  await _openHistory(t);
  final card = find.byIcon(Icons.chevron_right_rounded);
  if (card.evaluate().isEmpty) return;
  await t.tap(card.first, warnIfMissed: false);
  await _settle(t);
}

Future<void> _openProfile(WidgetTester t) async {
  await _tapNav(t, Icons.person_outline_rounded);
  await fx.scrollAll(t);
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
        envString: 'API_KEY=x\nAPI_BASE_URL=http://127.0.0.1:1/api\nAPI_DB=x');
  });
  tearDown(() => Product.isCustomerMode = false);

  final variants = <String, Future<void> Function(WidgetTester, String)?>{
    '': null,
    '/scrolled': (t, _) => fx.scrollAll(t),
    '/options': _openOptions,
    '/cart': (t, _) => _openCart(t),
    '/checkout': (t, _) => _openCheckout(t),
    '/history': (t, _) => _openHistory(t),
    '/history-scrolled': (t, _) async {
      await _openHistory(t);
      await fx.scrollAll(t);
    },
    '/order-detail': (t, _) => _openDetail(t),
    '/profile': (t, _) => _openProfile(t),
  };

  for (final cfg in layoutConfigs) {
    for (final loc in layoutLocales) {
      for (final v in variants.entries) {
        final suffix = v.key;
        final interact = v.value;
        testWidgets(
            'customer_self_order_screen${suffix.isEmpty ? '' : ' ($suffix)'} ${cfg.name} $loc',
            (t) async {
          await fx.seedPrefs();
          await http.runWithClient(
            () => surveyLayout(t,
                target: 'customer_self_order_screen$suffix',
                cfg: cfg,
                locale: loc,
                // Tap targets are checked where nothing is scrolled away.
                tapTargets: suffix != '/scrolled' &&
                    suffix != '/history-scrolled' &&
                    suffix != '/profile',
                probe: '35,000',
                build: () => const CustomerSelfOrderScreen(
                      customerName: _customerName,
                      userId: 9,
                      partnerId: 7,
                    ),
                pumps: const [
                  Duration.zero,
                  Duration(milliseconds: 300),
                  Duration(seconds: 1),
                  Duration(seconds: 3),
                ],
                interact: interact == null ? null : (t) => interact(t, loc)),
            _backend,
          );
        });
      }
    }
  }
}
