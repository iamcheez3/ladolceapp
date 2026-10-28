// Layout survey of the shared POS widgets at many screen sizes.
// See screen_size_harness_test.dart for what is recorded. Never fails on a
// layout issue; read the "LAYOUT|" lines.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/pos_tax_config.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/widgets/cart_sidebar.dart';
import 'package:ladolce/widgets/product_grid.dart';
import 'package:ladolce/widgets/product_list.dart';
import 'package:ladolce/widgets/topping_picker.dart';

import 'screen_size_harness_test.dart';

const longEn = 'Iced Caramel Macchiato with Extra Whipped Cream and Oat Milk';
const longLo = 'ກາເຟລາເຕ້ນົມສົດເຢັນພິເສດ ໃສ່ຄາຣາເມວ ແລະ ວິບຄຣີມ ນົມໂອັດ';

Topping top(int id, String en, String lo, int? group,
    {String type = 'single', bool req = false, bool def = false, double price = 0,
    String gEn = '', String gLo = '', int gseq = 10}) {
  return Topping.fromJson({
    'id': id,
    'name': en,
    'name_lo': lo,
    'extra_price': price,
    'sequence': id,
    'is_default': def,
    'group_id': group ?? false,
    'group_name': gEn,
    'group_name_lo': gLo,
    'group_sequence': gseq,
    'group_type': type,
    'group_required': req,
  });
}

final toppings = <Topping>[
  top(1, 'Hot', 'ຮ້ອນ', 10, req: true, def: true, gEn: 'Temperature', gLo: 'ອຸນຫະພູມ'),
  top(2, 'Iced', 'ເຢັນ', 10, req: true, gEn: 'Temperature', gLo: 'ອຸນຫະພູມ', price: 5000),
  top(3, 'Frappe blended', 'ປັ່ນ ແບບເຟຣັບເປ້', 10, req: true, gEn: 'Temperature', gLo: 'ອຸນຫະພູມ', price: 10000),
  top(4, 'Regular size', 'ຂະໜາດທຳມະດາ', 20, req: true, def: true, gEn: 'Cup size', gLo: 'ຂະໜາດຈອກ', gseq: 20),
  top(5, 'Large size (22 oz)', 'ຂະໜາດໃຫຍ່ພິເສດ (22 ອອນ)', 20, req: true, gEn: 'Cup size', gLo: 'ຂະໜາດຈອກ', gseq: 20, price: 15000),
  top(6, 'Less sweet 50%', 'ຫວານໜ້ອຍ 50%', 30, gEn: 'Sweetness level', gLo: 'ລະດັບຄວາມຫວານ', gseq: 30),
  top(7, 'No sugar at all', 'ບໍ່ໃສ່ນ້ຳຕານເລີຍ', 30, gEn: 'Sweetness level', gLo: 'ລະດັບຄວາມຫວານ', gseq: 30),
  top(8, 'Extra espresso shot', 'ເພີ່ມຊັອດເອສເປຣສໂຊ', null, price: 120000),
  top(9, 'Oat milk instead of dairy', 'ປ່ຽນເປັນນົມໂອັດ', null, price: 1234000),
  top(10, 'Whipped cream', 'ວິບຄຣີມ', null, price: 8000),
];

Product prod(int id, {String en = longEn, String lo = longLo, double price = 1234000,
    double? promo, String cat = 'Signature Coffee & Specialty Drinks', List<Topping> tops = const []}) {
  return Product(
    id: id,
    name: en,
    nameLo: lo,
    price: price,
    promotionPrice: promo,
    category: cat,
    toppings: tops,
  );
}

List<Product> products() => [
      prod(1),
      prod(2, en: 'Latte', lo: 'ລາເຕ້', price: 35000, cat: 'Coffee'),
      prod(3, promo: 999000, price: 12345000),
      prod(4, en: 'Mango Sticky Rice Bingsu Deluxe Sharing Bowl',
          lo: 'ບິງຊູເຂົ້າໜຽວໝາກມ່ວງ ຖ້ວຍໃຫຍ່ ແບ່ງກັນກິນ', price: 189000),
      prod(5, en: 'Croissant', lo: 'ຄົວຊອງ', price: 1234000, cat: 'Bakery'),
      prod(6),
      // No fixed price: the tile shows "Enter price".
      prod(7, en: 'Butter croissant', lo: 'ຄົວຊອງເນີຍ', price: 0, cat: 'Bakery'),
    ];

List<CartItem> cart() {
  final p = products();
  return [
    CartItem(product: p[3], quantity: 12, isSaved: true, isPrinted: true),
    CartItem(
      product: p[0],
      quantity: 99,
      selectedToppings: [toppings[2], toppings[4], toppings[5], toppings[7], toppings[8]],
      kitchenNote: 'ບໍ່ໃສ່ນ້ຳກ້ອນ, ຫວານໜ້ອຍ, ແຍກຖົງ — no ice, less sweet, separate bag please',
    ),
    CartItem(
      product: p[2],
      quantity: 1,
      isFreePromo: true,
      promotionName: 'Buy 2 Get 1 Free — Weekend Signature Promotion',
      selectedToppings: [toppings[1]],
    ),
    CartItem(product: p[4], quantity: 3),
  ];
}

/// Quantities already in the ticket (gold badges on the catalog).
const inCart = {1: 2, 3: 1000, 5: 12};

const customer = {
  'name': 'Souksavanh Phommachanh Vongsakda (VIP Gold Member)',
  'reward_points': 1234567,
};

/// Hosts the cart the way pos_screen does: inline rail (flex 3 of 8) at
/// width >= 800, else the 85 % bottom sheet.
Widget cartHost(Size size, PosTaxConfig tax, {bool named = false}) {
  final sidebar = CartSidebar(
    cartItems: cart(),
    onUpdateQuantity: (_, _) {},
    onClearCart: () {},
    onCharge: () {},
    onSaveTicket: () {},
    onViewTickets: () {},
    onEditKitchenNote: (_) {},
    onAddCustomer: () {},
    onClearCustomer: () {},
    selectedCustomer: customer,
    taxConfig: tax,
    ticketName: named ? 'Terrace table 12 (window side, near the garden)' : null,
    ticketSubtitle: named ? 'POS/2026/000123' : null,
    optionsButton: named
        ? IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz_rounded), tooltip: 'More')
        : null,
  );
  if (size.width >= 800) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: Row(children: [
        const Expanded(flex: 5, child: ColoredBox(color: Colors.white)),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: sidebar),
      ]),
    );
  }
  return Scaffold(
    body: SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(heightFactor: 0.85, child: sidebar),
      ),
    ),
  );
}

/// Same shape as the POS topping bottom sheet (pos_screen.dart ~950).
Widget toppingHost(bool cardStyle) {
  var sel = ToppingRules.defaults(toppings);
  return Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: StatefulBuilder(
        builder: (context, setState) => ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Select Toppings for ${products().first.displayName}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: ToppingPicker(
                      toppings: toppings,
                      selected: sel,
                      accent: const Color(0xFF001460),
                      addOnsTitle: 'Add-ons',
                      cardStyle: cardStyle,
                      onChanged: (n) => setState(() => sel = n),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Catalog area as in pos_screen: flex 5 of 8 next to the cart at >= 800.
Widget catalogHost(Size size, Widget catalog) => Scaffold(
      body: size.width >= 800
          ? Row(children: [
              Expanded(flex: 5, child: catalog),
              const VerticalDivider(width: 1),
              const Expanded(flex: 3, child: SizedBox()),
            ])
          : catalog,
    );

void main() {
  for (final cfg in layoutConfigs) {
    for (final loc in layoutLocales) {
      testWidgets('cart_sidebar (no tax) ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'cart_sidebar', cfg: cfg, locale: loc,
            build: () => cartHost(cfg.size, PosTaxConfig.disabled));
      });
      testWidgets('cart_sidebar (VAT 10% shown) ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'cart_sidebar+vat', cfg: cfg, locale: loc,
            build: () => cartHost(
                cfg.size,
                const PosTaxConfig(
                    active: true, percent: 10, inclusive: false, showOnReceipt: true)));
      });
      testWidgets('cart_sidebar (named ticket) ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'cart_sidebar+named', cfg: cfg, locale: loc,
            build: () => cartHost(cfg.size, PosTaxConfig.disabled, named: true));
      });
      testWidgets('topping_picker POS ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'topping_picker', cfg: cfg, locale: loc,
            build: () => toppingHost(false));
      });
      testWidgets('topping_picker card ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'topping_picker_card', cfg: cfg, locale: loc,
            build: () => toppingHost(true));
      });
      testWidgets('product_grid ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'product_grid', cfg: cfg, locale: loc,
            build: () => catalogHost(
                cfg.size, ProductGrid(products: products(), onProductTap: (_) {}, cartQuantities: inCart)));
      });
      testWidgets('product_list ${cfg.name} $loc', (t) async {
        await surveyLayout(t,
            target: 'product_list', cfg: cfg, locale: loc,
            build: () => catalogHost(
                cfg.size, ProductList(products: products(), onProductTap: (_) {}, cartQuantities: inCart)));
      });
    }
  }
}
