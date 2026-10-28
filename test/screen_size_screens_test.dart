// Layout survey of whole screens at many screen sizes. The backend is a
// fake (package:http MockClient via runWithClient) serving small fixtures
// with long English/Lao names and big ₭ amounts; everything else answers 404.
// See screen_size_harness_test.dart for what is recorded. Never fails on a
// layout issue; read the "LAYOUT|" lines.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/screens/login_screen.dart';
import 'package:ladolce/screens/maintenance_screen.dart';
import 'package:ladolce/screens/manage_items_screen.dart';
import 'package:ladolce/screens/manage_products_screen.dart';
import 'package:ladolce/screens/pin_screen.dart';
import 'package:ladolce/screens/pos_identity_screen.dart';
import 'package:ladolce/screens/pos_settings_screen.dart';
import 'package:ladolce/screens/product_edit_screen.dart';
import 'package:ladolce/screens/receipt_history_screen.dart';
import 'package:ladolce/screens/register_screen.dart';
import 'package:ladolce/screens/rider_screen.dart';
import 'package:ladolce/screens/self_orders_review_screen.dart';
import 'package:ladolce/screens/tickets_screen.dart';
import 'package:ladolce/screens/topping_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_size_harness_test.dart';

const longEn = 'Iced Caramel Macchiato with Extra Whipped Cream and Oat Milk';
const longLo = 'ກາເຟລາເຕ້ນົມສົດເຢັນພິເສດ ໃສ່ຄາຣາເມວ ແລະ ວິບຄຣີມ ນົມໂອັດ';

Map<String, dynamic> toppingJson(int id, String en, String lo, int? g,
        {double price = 0, bool req = false, bool def = false}) =>
    {
      'id': id,
      'name': en,
      'name_lo': lo,
      'extra_price': price,
      'sequence': id,
      'is_default': def,
      'group_id': g ?? false,
      'group_name': g == null ? '' : 'Cup size and temperature',
      'group_name_lo': g == null ? '' : 'ຂະໜາດຈອກ ແລະ ອຸນຫະພູມ',
      'group_sequence': 10,
      'group_type': 'single',
      'group_required': req,
    };

final fxToppings = [
  toppingJson(1, 'Hot', 'ຮ້ອນ', 10, req: true, def: true),
  toppingJson(2, 'Large size iced (22 oz)', 'ຂະໜາດໃຫຍ່ພິເສດ ເຢັນ (22 ອອນ)', 10,
      req: true, price: 15000),
  toppingJson(3, 'Oat milk instead of dairy', 'ປ່ຽນເປັນນົມໂອັດ', null, price: 1234000),
];

Map<String, dynamic> productJson(int id, String en, String lo, double price,
        {String cat = 'All / Saleable / Signature Coffee & Specialty Drinks',
        double? promo}) =>
    {
      'id': id,
      'name': en,
      'name_lo': lo,
      'list_price': price,
      'category': cat,
      'promotion_price': promo,
      'default_code': 'SKU-$id-LONG-REFERENCE',
      'qty_available': 1234,
      'toppings': fxToppings,
    };

final fxProducts = [
  productJson(1, longEn, longLo, 1234000),
  productJson(2, 'Latte', 'ລາເຕ້', 35000, cat: 'Coffee'),
  productJson(3, 'Mango Sticky Rice Bingsu Deluxe Sharing Bowl',
      'ບິງຊູເຂົ້າໜຽວໝາກມ່ວງ ຖ້ວຍໃຫຍ່ ແບ່ງກັນກິນ', 12345000, promo: 999000),
  productJson(4, 'Croissant', 'ຄົວຊອງ', 1234000, cat: 'Bakery'),
];

final fxCategories = [
  {'id': 1, 'name': 'Signature Coffee & Specialty Drinks', 'name_lo': 'ກາເຟພິເສດ ແລະ ເຄື່ອງດື່ມ'},
  {'id': 2, 'name': 'Coffee', 'name_lo': 'ກາເຟ'},
  {'id': 3, 'name': 'Bakery', 'name_lo': 'ເບເກີລີ'},
];

final fxGroups = [
  {'id': 10, 'name': 'Cup size and temperature', 'name_lo': 'ຂະໜາດຈອກ ແລະ ອຸນຫະພູມ',
   'sequence': 10, 'selection_type': 'single', 'required': true},
];

Map<String, dynamic> ticketJson(int id, String label, {String? table}) => {
      'id': id,
      'name': 'Order 000$id-123-4567',
      'queue_number': 1000 + id,
      'table_id': table == null ? null : id,
      'table_name': table,
      'ticket_label': label,
      'amount_total': 258687000,
      'payment_type': '',
      'opened_at': DateTime.now()
          .subtract(Duration(hours: id * 3, minutes: 7))
          .toUtc()
          .toIso8601String(),
      'partner_id': 7,
      'partner_name': 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
      'note': 'ບໍ່ໃສ່ນ້ຳກ້ອນ, ຫວານໜ້ອຍ — no ice, less sweet, separate bag',
      'is_self_order': id.isEven,
      'delivery_status': id == 3 ? 'delivering' : 'none',
      'lines': [
        {'product_id': 1, 'product_name': longEn, 'product_name_lo': longLo,
         'qty': 99, 'price_unit': 2613000, 'topping_ids': [2, 3],
         'note': 'extra hot please'},
        {'product_id': 3, 'product_name': 'Mango Sticky Rice Bingsu Deluxe Sharing Bowl',
         'qty': 1, 'price_unit': 0, 'is_free_promo': true},
      ],
    };

final fxTickets = [
  ticketJson(1, 'Table VIP Room 12 — Terrace (window side)', table: 'VIP Room 12 — Terrace'),
  ticketJson(2, 'ໂຕະ ຫ້ອງ VIP ຊັ້ນສອງ ຕິດປ່ອງຢ້ຽມ'),
  ticketJson(3, 'Delivery — Souksavanh'),
];

Map<String, dynamic> receiptJson(int i) => {
      'id': 100 + i,
      'order_id': 100 + i,
      'name': 'LaDolce Main Branch/POS 01/000${i}2345',
      'order_reference': 'Order 00012-001-000$i',
      'date_order': '2026-10-2${i % 9} 1$i:3$i:00',
      'date_paid': '2026-10-2${i % 9} 1$i:4$i:00',
      'amount_total': 1234567000 + i,
      'amount_discount': i.isEven ? 123456000 : 0,
      'payment_method': i.isEven ? 'BCEL OnePay QR (Bank transfer)' : 'Cash',
      'synced': i != 2,
      'offline': i == 2,
      'state': 'paid',
      'partner_name': 'Souksavanh Phommachanh Vongsakda',
    };

Map<String, dynamic> selfOrderJson(int id, String pay) => {
      'id': id,
      'name': 'Order 000$id-123-4567-SELF',
      'table_name': 'VIP Room 12 — Terrace (window side)',
      'customer': 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
      'customer_phone': '020 5555 1234',
      'amount_total': 258687000,
      'payment_type': pay,
      'transfer_proof_url': pay == 'transfer' ? '/web/image/1' : '',
      'note': 'ບໍ່ໃສ່ນ້ຳກ້ອນ, ຫວານໜ້ອຍ — no ice, less sweet, pick up at 3 PM',
      'delivery_place_name': 'Vientiane Center Mall, Tower B, 12th floor',
      'delivery_place_address': 'Khouvieng Road, Nongchan Village, Sisattanak District',
      'delivery_maps_url': 'https://maps.google.com/?q=17.96,102.61',
      'lines': [
        {'product_name': longEn, 'product_name_lo': longLo, 'qty': 99,
         'subtotal': 258687000, 'toppings': [{'name': 'Oat milk instead of dairy'}],
         'note': 'extra hot please'},
        {'product_name': 'Croissant', 'qty': 1, 'subtotal': 0},
      ],
    };

Map<String, dynamic> riderOrderJson(int id, String status) => {
      'id': id,
      'order_reference': 'Order 00012-001-000$id-DELIVERY',
      'customer_name': 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
      'customer_phone': '020 5555 1234',
      'delivery_place_name': 'Vientiane Center Mall, Tower B, 12th floor',
      'delivery_place_address': 'Khouvieng Road, Nongchan Village, Sisattanak District',
      'delivery_status': status,
      'delivery_maps_url': 'https://maps.google.com/?q=17.96,102.61',
      'amount_total': 258687000,
      'note': 'ບໍ່ໃສ່ນ້ຳກ້ອນ — call when you arrive at the lobby',
      'lines': [
        {'product_name': longEn, 'product_name_lo': longLo, 'qty': 99,
         'subtotal': 258687000, 'note': 'extra hot'},
      ],
    };

final cachedUser = {
  'user_id': 5,
  'name': 'Khamphoui Sengdara Phommavong (Senior Cashier)',
  'role': 'admin',
  'pos_pin': '1111',
  'pos_name': 'LaDolce POS Counter 01 — Main Branch',
  'branch_name': 'LaDolce Vientiane Center Mall (Ground Floor)',
  'branch_id': 1,
  'tax_active': true,
  'tax_percent': 10,
  'tax_inclusive': true,
  'tax_show_on_receipt': true,
};

http.Client fakeBackend([List<Map<String, dynamic>>? products]) =>
    MockClient((req) async {
      final p = req.url.path;
      Object? data;
      if (p.endsWith('/products')) {
        data = req.url.queryParameters['offset'] == '0'
            ? (products ?? fxProducts)
            : [];
      } else if (p.endsWith('/pos/toppings')) {
        data = fxToppings;
      } else if (p.endsWith('/pos/topping_groups')) {
        data = fxGroups;
      } else if (p.endsWith('/pos/categories')) {
        data = fxCategories;
      } else if (p.endsWith('/pos/open_tickets')) {
        data = fxTickets;
      } else if (p.endsWith('/pos/history/paginated')) {
        data = {
          'receipts': [for (var i = 1; i <= 8; i++) receiptJson(i)],
          'has_more': false,
          'total_count': 8,
        };
      } else if (p.endsWith('/pos/payment_methods')) {
        data = [
          {'id': 1, 'name': 'Cash', 'open_cash_drawer': true},
          {'id': 2, 'name': 'BCEL OnePay QR (Bank transfer)'},
          {'id': 3, 'name': 'ເງິນໂອນ ທະນາຄານການຄ້າ'},
        ];
      } else if (p.endsWith('/pos/branches/public') || p.endsWith('/pos/branches')) {
        data = [
          {'id': 1, 'name': 'LaDolce Vientiane Center Mall (Ground Floor)'},
          {'id': 2, 'name': 'ລາໂດລເຊ ສາຂາ ຕະຫຼາດເຊົ້າມໍລ ຊັ້ນສອງ'},
        ];
      } else if (p.endsWith('/pos/self_orders/pending')) {
        data = [selfOrderJson(1, 'transfer'), selfOrderJson(2, 'pay_at_store')];
      } else if (p.endsWith('/pos/rider/orders')) {
        data = [
          riderOrderJson(1, 'pending'),
          riderOrderJson(2, 'on_the_way'),
          riderOrderJson(3, 'arrived'),
          riderOrderJson(4, 'delivered'),
        ];
      } else if (p.endsWith('/pos/tables')) {
        data = [
          for (var i = 1; i <= 6; i++)
            {'id': i, 'name': 'Table VIP Room $i — Terrace', 'capacity': 8,
             'status': i == 2 ? 'occupied' : 'available', 'has_open_order': i == 2},
        ];
      }
      if (data == null) {
        return http.Response(jsonEncode({'status': 'error', 'message': 'not faked'}), 404);
      }
      return http.Response.bytes(
          utf8.encode(jsonEncode({'status': 'success', 'data': data})), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

Future<void> seedPrefs() async {
  SharedPreferences.setMockInitialValues({
    'cached_user_data': jsonEncode(cachedUser),
    'cached_user_session': 'test-session',
    'cached_products': jsonEncode(fxProducts),
    'cached_toppings': jsonEncode(fxToppings),
    'cached_categories': jsonEncode(fxCategories),
    'cached_payment_methods': jsonEncode([
      {'id': 1, 'name': 'Cash', 'open_cash_drawer': true},
      {'id': 2, 'name': 'BCEL OnePay QR (Bank transfer)'},
    ]),
  });
}

Product fxProduct() => Product.fromJson(fxProducts.first);
Topping fxTopping() => Topping.fromJson(fxToppings[1]);

typedef ScreenBuilder = Widget Function();

/// Text that must be on screen once the fixtures loaded (else "no-data").
const probes = <String, String>{
  'tickets_screen': '0001-123',
  'manage_products_screen': '35,000',
  'receipt_history_screen': '1,234,567,00',
  'self_orders_review_screen': '0001-123',
  'rider_screen': '00012-001',
  'product_edit_screen': 'Iced Caramel',
};

final screens = <String, ScreenBuilder>{
  'login_screen': () => const LoginScreen(),
  'pin_screen': () => PinScreen(cachedUser: cachedUser),
  'pin_screen(setup)': () => PinScreen(cachedUser: {...cachedUser, 'pos_pin': ''}),
  'pos_settings_screen': () => const PosSettingsScreen(),
  'tickets_screen': () => TicketsScreen(
      cachedProducts: fxProducts.map(Product.fromJson).toList()),
  'manage_items_screen': () => const ManageItemsScreen(),
  'manage_products_screen': () => const ManageProductsScreen(),
  'product_edit_screen': () => ProductEditScreen(
        product: fxProduct(),
        categories: jsonDecode(jsonEncode(fxCategories)) as List<dynamic>,
        toppings: fxToppings.map(Topping.fromJson).toList(),
      ),
  'topping_edit_screen': () => ToppingEditScreen(topping: fxTopping()),
  'receipt_history_screen': () => const ReceiptHistoryScreen(),
  'register_screen': () => const RegisterScreen(),
  'register_screen(staff)': () => const RegisterScreen(showStaffRoles: true),
  'pos_identity_screen': () => PosIdentityScreen(user: cachedUser),
  'maintenance_screen': () => const MaintenanceScreen(
        messageEn: 'We are upgrading the LaDolce point of sale system tonight. '
            'Ordering will be back at 06:00 Vientiane time. Thank you for your patience.',
        messageLo: 'ພວກເຮົາກຳລັງປັບປຸງລະບົບຂາຍໜ້າຮ້ານ LaDolce ຄືນນີ້. '
            'ຈະກັບມາສັ່ງໄດ້ເວລາ 06:00 ໂມງ. ຂອບໃຈທີ່ລໍຖ້າ.',
      ),
  'self_orders_review_screen': () => const SelfOrdersReviewScreen(),
  'rider_screen': () => const RiderScreen(
      riderName: 'Khamphoui Sengdara Phommavong', riderId: 5),
};

/// Scroll every scrollable to the end so content below the fold is laid out
/// and scanned too (scan runs again after scrolling).
Future<void> scrollAll(WidgetTester t) async {
  final scrollables = find.byType(Scrollable).evaluate().toList();
  for (final e in scrollables) {
    final state = (e as StatefulElement).state;
    if (state is ScrollableState) {
      final pos = state.position;
      if (pos.hasContentDimensions && pos.maxScrollExtent > 0 &&
          pos.axis == Axis.vertical) {
        pos.jumpTo(pos.maxScrollExtent);
      }
    }
  }
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(
        envString: 'API_KEY=x\nAPI_BASE_URL=http://127.0.0.1:1/api\nAPI_DB=x');
  });

  for (final entry in screens.entries) {
    for (final cfg in layoutConfigs) {
      for (final loc in layoutLocales) {
        testWidgets('${entry.key} ${cfg.name} $loc', (t) async {
          await seedPrefs();
          await http.runWithClient(
            () => surveyLayout(t,
                target: entry.key, cfg: cfg, locale: loc,
                build: entry.value,
                probe: probes[entry.key],
                pumps: const [
                  Duration.zero,
                  Duration(milliseconds: 200),
                  Duration(seconds: 1),
                  Duration(seconds: 2),
                ]),
            fakeBackend,
          );
        });
        testWidgets('${entry.key} (scrolled) ${cfg.name} $loc', (t) async {
          await seedPrefs();
          await http.runWithClient(
            () => surveyLayout(t,
                target: '${entry.key}/scrolled', cfg: cfg, locale: loc,
                build: entry.value,
                tapTargets: false,
                pumps: const [
                  Duration.zero,
                  Duration(milliseconds: 200),
                  Duration(seconds: 1),
                  Duration(seconds: 2),
                ],
                interact: scrollAll),
            fakeBackend,
          );
        });
      }
    }
  }
}
