// Layout survey of the items-management and admin/settings screens at many
// screen sizes (Oct 2026 redesign). Same approach as
// screen_size_screens_test.dart: a fake backend (package:http MockClient via
// runWithClient) serves small fixtures with long English/Lao names and big ₭
// amounts; everything else answers 404. Never fails on a layout issue; read
// the "LAYOUT|" lines (see screen_size_harness_test.dart).
//
// Run one screen only with:  flutter test test/screen_size_admin_test.dart
//   --plain-name "pos_settings_screen "

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ladolce/models/pos_discount_config.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/screens/admin_reports_screen.dart';
import 'package:ladolce/screens/bill_template_settings_screen.dart';
import 'package:ladolce/screens/category_edit_screen.dart';
import 'package:ladolce/screens/combo_edit_screen.dart';
import 'package:ladolce/screens/customer_support_screen.dart';
import 'package:ladolce/screens/discount_config_screen.dart';
import 'package:ladolce/screens/manage_categories_screen.dart';
import 'package:ladolce/screens/manage_combos_screen.dart';
import 'package:ladolce/screens/manage_items_screen.dart';
import 'package:ladolce/screens/manage_products_screen.dart';
import 'package:ladolce/screens/manage_topping_groups_screen.dart';
import 'package:ladolce/screens/manage_toppings_screen.dart';
import 'package:ladolce/screens/pos_settings_screen.dart';
import 'package:ladolce/screens/printer_edit_screen.dart';
import 'package:ladolce/screens/printer_settings_screen.dart';
import 'package:ladolce/screens/privacy_policy_screen.dart';
import 'package:ladolce/screens/product_edit_screen.dart';
import 'package:ladolce/screens/ranking_screen.dart';
import 'package:ladolce/screens/share_card_screen.dart';
import 'package:ladolce/screens/topping_edit_screen.dart';
import 'package:ladolce/services/printer_service.dart';
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
  toppingJson(3, 'Oat milk instead of dairy', 'ປ່ຽນເປັນນົມໂອັດ', null,
      price: 1234000),
  toppingJson(4, 'Whipped cream topping', 'ວິບຄຣີມ', null, price: 5000),
];

Map<String, dynamic> productJson(int id, String en, String lo, double price,
        {String cat = 'All / Saleable / Signature Coffee & Specialty Drinks',
        double? promo,
        bool posOnly = false}) =>
    {
      'id': id,
      'name': en,
      'name_lo': lo,
      'list_price': price,
      'category': cat,
      'categ_id': 1,
      'promotion_price': promo,
      'default_code': 'SKU-$id-LONG-REFERENCE',
      'qty_available': 1234,
      'pos_only': posOnly,
      'toppings': fxToppings,
    };

final fxProducts = [
  productJson(1, longEn, longLo, 1234000),
  productJson(2, 'Latte', 'ລາເຕ້', 35000, cat: 'Coffee'),
  productJson(3, 'Mango Sticky Rice Bingsu Deluxe Sharing Bowl',
      'ບິງຊູເຂົ້າໜຽວໝາກມ່ວງ ຖ້ວຍໃຫຍ່ ແບ່ງກັນກິນ', 12345000,
      promo: 999000),
  productJson(4, 'Croissant', 'ຄົວຊອງ', 0, cat: 'Bakery', posOnly: true),
];

final fxCategories = [
  {'id': 1, 'name': 'Signature Coffee & Specialty Drinks', 'name_lo': 'ກາເຟພິເສດ ແລະ ເຄື່ອງດື່ມ', 'parent_id': false, 'is_visible': true},
  {'id': 2, 'name': 'Coffee', 'name_lo': 'ກາເຟ', 'parent_id': 1, 'is_visible': true},
  {'id': 3, 'name': 'Bakery', 'name_lo': 'ເບເກີລີ', 'parent_id': false, 'is_visible': false},
];

final fxGroups = [
  {'id': 10, 'name': 'Cup size and temperature', 'name_lo': 'ຂະໜາດຈອກ ແລະ ອຸນຫະພູມ',
   'sequence': 10, 'selection_type': 'single', 'required': true},
  {'id': 11, 'name': 'Sweetness', 'name_lo': 'ລົດຊາດ ຫວານ',
   'sequence': 20, 'selection_type': 'multi', 'required': false},
];

final fxCombos = [
  {
    'id': 1,
    'name': 'Breakfast set: Americano, croissant and fruit cup (big)',
    'price': 1234000,
    'lines': [
      {'id': 1, 'product_id': 1, 'product_name': longEn, 'qty': 2},
      {'id': 2, 'product_id': 4, 'product_name': 'Croissant', 'qty': 1},
    ],
  },
];

Map<String, dynamic> fxReport() => {
      'grand_total': 1923456789,
      'order_count': 2861,
      'sales_by_day': [
        for (var d = 20; d <= 28; d++)
          {'date': '2026-10-$d', 'total': 120000000 + d * 4567000, 'order_count': 300 + d},
      ],
      'sales_by_payment_method': [
        {'payment_method': 'Cash', 'total': 987000000, 'transactions': 1500},
        {'payment_method': 'BCEL OnePay QR (Bank transfer)', 'total': 764000000, 'transactions': 1200},
        {'payment_method': 'ເງິນໂອນ ທະນາຄານການຄ້າ', 'total': 169400000, 'transactions': 161},
      ],
      'sales_by_product': [
        {'name': longEn, 'total': 582400000, 'qty': 182},
        {'name': 'Latte', 'total': 423500000, 'qty': 121},
        {'name': 'ບິງຊູເຂົ້າໜຽວໝາກມ່ວງ ຖ້ວຍໃຫຍ່ ແບ່ງກັນກິນ', 'total': 281200000, 'qty': 74},
        {'name': 'Croissant', 'total': 175500000, 'qty': 39},
      ],
      'sales_by_branch': [
        {'branch_id': 1, 'branch_name': 'LaDolce Vientiane Center Mall (Ground Floor)', 'total': 1500000000},
        {'branch_id': 2, 'branch_name': 'ລາໂດລເຊ ສາຂາ ຕະຫຼາດເຊົ້າມໍລ ຊັ້ນສອງ', 'total': 423456789},
      ],
      'sales_by_hour': [
        for (var h = 7; h <= 21; h++)
          {'hour': h, 'order_count': (h * 37) % 120 + 5, 'total': ((h * 37) % 120 + 5) * 67000},
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
  'reward_points': 1234,
  'tax_active': true,
  'tax_percent': 10,
  'tax_inclusive': true,
  'tax_show_on_receipt': true,
};

http.Response _ok(Object data) => http.Response.bytes(
    utf8.encode(jsonEncode({'status': 'success', 'data': data})), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

http.Client fakeBackend() => MockClient((req) async {
      final p = req.url.path;
      Object? data;
      if (p.endsWith('/products')) {
        data = req.url.queryParameters['offset'] == '0' ? fxProducts : [];
      } else if (p.endsWith('/pos/toppings')) {
        data = fxToppings;
      } else if (p.endsWith('/pos/topping_groups')) {
        data = fxGroups;
      } else if (p.endsWith('/pos/categories')) {
        data = fxCategories;
      } else if (p.endsWith('/pos/combos')) {
        data = fxCombos;
      } else if (p.endsWith('/pos/reports/summary')) {
        data = fxReport();
      } else if (p.endsWith('/pos/ranking/top50')) {
        data = [
          for (var i = 1; i <= 12; i++)
            {'rank': i, 'name': i.isEven ? 'Souksavanh Phommachanh Vongsakda' : 'ສຸກສະຫວັນ ພົມມະຈັນ', 'reward_points': 99999 - i * 1234},
        ];
      } else if (p.endsWith('/privacy-policy')) {
        data = {
          'last_updated': 'October 28, 2026',
          'sections': [
            for (var i = 1; i <= 4; i++)
              {'title': 'Section $i: how we use your personal information', 'content': 'ພວກເຮົາເກັບຂໍ້ມູນ ' * 20},
          ],
        };
      } else if (p.endsWith('/pos/payment_methods')) {
        data = [
          {'id': 1, 'name': 'Cash', 'open_cash_drawer': true},
          {'id': 2, 'name': 'BCEL OnePay QR (Bank transfer)'},
        ];
      } else if (p.endsWith('/pos/branches/public') || p.endsWith('/pos/branches')) {
        data = [
          {'id': 1, 'name': 'LaDolce Vientiane Center Mall (Ground Floor)', 'code': 'VTE-01'},
          {'id': 2, 'name': 'ລາໂດລເຊ ສາຂາ ຕະຫຼາດເຊົ້າມໍລ ຊັ້ນສອງ'},
        ];
      }
      if (data == null) {
        return http.Response(jsonEncode({'status': 'error', 'message': 'not faked'}), 404);
      }
      return _ok(data);
    });

final fxPrinters = [
  {
    'id': 'p1',
    'name': 'Front counter receipt printer (Epson TM-T82)',
    'ip': '192.168.100.194',
    'port': 9100,
    'paperWidthMm': 80,
    'printReceiptsAndBills': true,
    'printOrders': false,
  },
  {
    'id': 'p2',
    'name': 'ເຄື່ອງພິມໃນຄົວ ເຄື່ອງດື່ມ ແລະ ເຄັກ',
    'ip': '192.168.100.250',
    'port': 9100,
    'paperWidthMm': 58,
    'printReceiptsAndBills': false,
    'printOrders': true,
    'categoryFilters': ['Signature Coffee & Specialty Drinks', 'Bakery'],
  },
];

Future<void> seedPrefs() async {
  SharedPreferences.setMockInitialValues({
    'cached_user_data': jsonEncode(cachedUser),
    'cached_user_session': 'test-session',
    'cached_products': jsonEncode(fxProducts),
    'cached_toppings': jsonEncode(fxToppings),
    'cached_categories': jsonEncode(fxCategories),
    'cached_combos': jsonEncode(fxCombos),
    'printer_profiles_v1': jsonEncode(fxPrinters),
    'receipt_printer_id_v1': 'p1',
    'rejected_orders': [
      jsonEncode({
        'at': '2026-10-28T12:34:56.000',
        'action': 'create',
        'reason': 'Product is archived: $longEn',
        'total': 1234000,
        'lines': 2,
        'payload': {},
      }),
    ],
    'cached_payment_methods': jsonEncode([
      {'id': 1, 'name': 'Cash', 'open_cash_drawer': true},
      {'id': 2, 'name': 'BCEL OnePay QR (Bank transfer)'},
    ]),
  });
}

typedef ScreenBuilder = Widget Function();

/// Text that must be on screen once the fixtures loaded (else "no-data").
const probes = <String, String>{
  'manage_products_screen': '35,000',
  'product_edit_screen': 'Iced Caramel',
  'manage_toppings_screen': 'Oat milk',
  'manage_topping_groups_screen': 'Sweetness',
  'manage_categories_screen': 'Bakery',
  // manage_combos_screen: fetchCombos() always returns [] (combos hidden),
  // so it shows its empty state.
  'printer_settings_screen': '192.168.100.194',
};

final screens = <String, ScreenBuilder>{
  'manage_items_screen': () => const ManageItemsScreen(),
  'manage_products_screen': () => const ManageProductsScreen(),
  'product_edit_screen': () => ProductEditScreen(
        product: Product.fromJson(fxProducts.first),
        categories: jsonDecode(jsonEncode(fxCategories)) as List<dynamic>,
        toppings: fxToppings.map(Topping.fromJson).toList(),
      ),
  'product_edit_screen(new)': () => ProductEditScreen(
        categories: jsonDecode(jsonEncode(fxCategories)) as List<dynamic>,
        toppings: fxToppings.map(Topping.fromJson).toList(),
      ),
  'manage_categories_screen': () => const ManageCategoriesScreen(),
  'category_edit_screen': () => CategoryEditScreen(
        category: jsonDecode(jsonEncode(fxCategories[1])) as Map<String, dynamic>,
        categories: jsonDecode(jsonEncode(fxCategories)) as List<dynamic>,
      ),
  'manage_toppings_screen': () => const ManageToppingsScreen(),
  'topping_edit_screen': () => ToppingEditScreen(topping: Topping.fromJson(fxToppings[1])),
  'manage_topping_groups_screen': () => const ManageToppingGroupsScreen(),
  'manage_combos_screen': () => const ManageCombosScreen(),
  'combo_edit_screen': () => ComboEditScreen(
        combo: jsonDecode(jsonEncode(fxCombos.first)) as Map<String, dynamic>,
        allProducts: fxProducts.map(Product.fromJson).toList(),
      ),
  'pos_settings_screen': () => const PosSettingsScreen(),
  'printer_settings_screen': () => const PrinterSettingsScreen(),
  'printer_edit_screen': () =>
      PrinterEditScreen(profile: PrinterProfile.fromJson(fxPrinters[1])),
  'bill_template_settings_screen': () => const BillTemplateSettingsScreen(),
  'discount_config_screen': () => DiscountConfigScreen(
        initialConfig: PosDiscountConfig(enabled: true, options: [
          PosDiscountOption(id: 'a', type: 'percentage', value: 10, name: 'Discount 10% for staff and family members'),
          PosDiscountOption(id: 'b', type: 'value', value: 1234000, name: 'ສ່ວນຫຼຸດ ເງິນສົດ'),
          PosDiscountOption(id: 'c', type: 'value', name: 'Discount Value'),
        ]),
      ),
  'admin_reports_screen': () => const AdminReportsScreen(),
  'admin_reports_screen(home)': () => const AdminReportsScreen(asAdminHome: true),
  'ranking_screen': () => const RankingScreen(
        myRank: 12,
        myPoints: 1234567,
        myName: 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
        myImageBase64: null,
      ),
  'customer_support_screen': () => const CustomerSupportScreen(
        facebookUrl: 'https://facebook.com/ladolce.vientiane.coffee',
        whatsappNumber: '+856 20 5555 1234',
        whatsappLink: 'https://wa.me/8562055551234',
      ),
  'privacy_policy_screen': () => const PrivacyPolicyScreen(),
  'share_card_screen': () => const ShareCardScreen(
        name: 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
        points: 1234567,
        rank: 12,
      ),
  'share_card_screen(no rank)': () => const ShareCardScreen(
        name: 'ສຸກສະຫວັນ',
        points: 0,
        rank: 0,
      ),
};

/// Scroll every vertical scrollable to the end so content below the fold is
/// laid out and scanned too.
Future<void> scrollAll(WidgetTester t) async {
  final scrollables = find.byType(Scrollable).evaluate().toList();
  for (final e in scrollables) {
    final state = (e as StatefulElement).state;
    if (state is ScrollableState) {
      final pos = state.position;
      if (pos.hasContentDimensions &&
          pos.maxScrollExtent > 0 &&
          pos.axis == Axis.vertical) {
        pos.jumpTo(pos.maxScrollExtent);
      }
    }
  }
  await t.pump(const Duration(milliseconds: 100));
}

const _pumps = [
  Duration.zero,
  Duration(milliseconds: 200),
  Duration(seconds: 1),
  Duration(seconds: 2),
];

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
                target: entry.key,
                cfg: cfg,
                locale: loc,
                build: entry.value,
                probe: probes[entry.key],
                pumps: _pumps),
            fakeBackend,
          );
        });
        testWidgets('${entry.key} (scrolled) ${cfg.name} $loc', (t) async {
          await seedPrefs();
          await http.runWithClient(
            () => surveyLayout(t,
                target: '${entry.key}/scrolled',
                cfg: cfg,
                locale: loc,
                build: entry.value,
                tapTargets: false,
                pumps: _pumps,
                interact: scrollAll),
            fakeBackend,
          );
        });
      }
    }
  }
}
