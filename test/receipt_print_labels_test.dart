import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/services/printer_service.dart';
import 'package:ladolce/utils/localized_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool _containsBytes(List<int> bytes, List<int> pattern) {
  for (var i = 0; i <= bytes.length - pattern.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

/// Binds a throwaway ESC/POS printer and returns every byte it was sent,
/// plus how long the app kept the connection open.
Future<({List<int> bytes, Duration open})> _capture(
  Future<void> Function(PrinterProfile profile) print,
) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final received = <int>[];
  final closed = Completer<Duration>();
  server.listen((socket) {
    final watch = Stopwatch()..start();
    socket.listen(
      received.addAll,
      onDone: () {
        if (!closed.isCompleted) closed.complete(watch.elapsed);
      },
    );
  });
  try {
    await print(
      PrinterProfile(
        id: 'virtual',
        name: 'bar',
        ip: InternetAddress.loopbackIPv4.address,
        port: server.port,
        paperWidthMm: 58,
      ),
    );
    final open = await closed.future.timeout(const Duration(seconds: 3));
    return (bytes: received, open: open);
  } finally {
    await server.close();
  }
}

Product _product(String name, String nameLo, double price) => Product(
  id: name.hashCode,
  name: name,
  nameLo: nameLo,
  price: price,
  category: 'Coffee',
);

final _hot = Topping(
  id: 1,
  name: 'Hot',
  nameLo: 'ຮ້ອນ',
  groupId: 7,
  groupName: 'Type',
  groupSequence: 1,
);
final _sizeL = Topping(
  id: 2,
  name: 'Size L',
  nameLo: 'ຂະໜາດ L',
  extraPrice: 5000,
  groupId: 8,
  groupName: 'Size',
  groupSequence: 3,
);

List<String> _text(List<PrintLine> lines) =>
    lines.map((l) => l.toString()).toList();

void main() {
  group('ReceiptPrintLabels', () {
    test('stays English even when the app is in Lao', () {
      final oldLanguage = DisplayLanguage.code;
      DisplayLanguage.code = 'lo';
      try {
        const labels = ReceiptPrintLabels.english;

        expect(labels.date, 'Date');
        expect(labels.cashier, 'Cashier');
        expect(labels.total, 'TOTAL');
        expect(labels.orderTicket, 'Order Ticket');
        expect(labels.note, 'NOTE');
      } finally {
        DisplayLanguage.code = oldLanguage;
      }
    });
  });

  group('Receipt layout', () {
    final items = [
      CartItem(
        product: _product('Americano', 'ອາເມລິກາໂນ', 30000),
        selectedToppings: [_sizeL, _hot],
      ),
      CartItem(
        product: _product('Brownie', 'ບຣາວນີ້', 35000),
        isFreePromo: true,
        promotionId: 4,
      ),
    ];

    List<String> receipt({ReceiptCustomer? customer}) => _text(
      PrintLayouts.receipt(
        items: items,
        subtotal: 35000,
        tax: 0,
        total: 35000,
        cashierName: 'Sith Cashier',
        headerText: 'LaDolce\nLaDolce Main, Vientiane',
        footerText: '',
        payments: const [
          ReceiptPayment('Transfer (BCEL OnePay)', 30000),
          ReceiptPayment('Cash', 7000),
        ],
        changeAmount: 2000,
        customer: customer,
        at: DateTime(2026, 10, 10, 19, 49, 1),
      ),
    );

    test('starts with the logo and the bill template header', () {
      final lines = receipt();
      expect(lines.take(3), ['[logo]', 'LaDolce', 'LaDolce Main, Vientiane']);
      expect(lines, isNot(contains('Point of Sale')));
      expect(lines.where((l) => l.startsWith('Printer')), isEmpty);
      expect(lines, contains('Date: 2026-10-10 19:49:01'));
    });

    test('prints prices as "LAK 35000.00", choices and FREE items', () {
      final lines = receipt();
      expect(lines, contains('1x Americano | LAK 35000.00'));
      // Grouped choices follow group order (Type before Size).
      final hot = lines.indexOf('+ Hot');
      final size = lines.indexOf('+ Size L');
      expect(hot, greaterThan(0));
      expect(size, hot + 1);
      expect(lines, contains('1x Brownie (FREE) | LAK 0.00'));
      expect(lines, contains('TOTAL: | LAK 35000.00'));
    });

    test('lists every payment of a split payment and the change', () {
      final lines = receipt();
      final total = lines.indexOf('TOTAL: | LAK 35000.00');
      expect(lines.sublist(total + 1, total + 4), [
        'Transfer (BCEL OnePay) | LAK 30000.00',
        'Cash | LAK 7000.00',
        'Change | LAK 2000.00',
      ]);
    });

    test('prints the customer, points earned and total points', () {
      final lines = receipt(
        customer: const ReceiptCustomer(
          name: 'test',
          pointsEarned: 3,
          totalPoints: 120,
        ),
      );
      expect(lines, containsAllInOrder([
        'Customer: test',
        'Points earned | +3',
        'Total Points | 120',
      ]));
    });

    test('falls back to a thank-you line without a footer', () {
      expect(receipt(), contains('Thank you, see you again'));
    });

    test('menu and choice names follow the app language', () {
      final oldLanguage = DisplayLanguage.code;
      DisplayLanguage.code = 'lo';
      try {
        final lines = receipt();
        expect(lines, contains('1x ອາເມລິກາໂນ | LAK 35000.00'));
        expect(lines, contains('+ ຮ້ອນ'));
        expect(lines, contains('Cashier: Sith Cashier'));
      } finally {
        DisplayLanguage.code = oldLanguage;
      }
    });
  });

  group('Kitchen ticket layout', () {
    test('is titled "Order Ticket" with no printer line', () {
      final lines = _text(
        PrintLayouts.orderTicket(
          items: [
            CartItem(
              product: _product('Americano', 'ອາເມລິກາໂນ', 30000),
              quantity: 2,
              selectedToppings: [_hot],
            ),
            CartItem(
              product: _product('Cappuccino', 'ກາປູຊີໂນ', 35000),
              isFreePromo: true,
              promotionId: 4,
            ),
          ],
          cashierName: 'Sith Cashier',
          queueNumber: 18,
        ),
      );
      expect(lines.first, 'Order Ticket');
      expect(lines, contains('#018'));
      expect(lines.where((l) => l.startsWith('Printer')), isEmpty);
      expect(lines, containsAllInOrder(['2x Americano', '+ Hot']));
      expect(lines, contains('1x Cappuccino (FREE)'));
    });

    test('groups identical lines, but not a free one with a paid one', () {
      final americano = _product('Americano', '', 30000);
      final lines = _text(
        PrintLayouts.orderTicket(
          items: [
            CartItem(product: americano),
            CartItem(product: americano),
            CartItem(product: americano, isFreePromo: true, promotionId: 1),
          ],
          cashierName: 'c',
        ),
      );
      expect(lines, contains('2x Americano'));
      expect(lines, contains('1x Americano (FREE)'));
    });
  });

  group('Printing to a network printer', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('a Lao kitchen note still prints the whole ticket', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final oldLanguage = DisplayLanguage.code;
        DisplayLanguage.code = 'lo';
        try {
          final sent = await _capture(
            (profile) => PrinterService().printOrderTicketDirect(
              profile: profile,
              items: [
                CartItem(
                  product: _product('Almond croissant', 'ຄົວຊອງອາມອນ', 40000),
                  selectedToppings: [_hot],
                  kitchenNote: 'ບໍ່ໃສ່ນ້ຳຕານ\nໃສ່ນົມໜ້ອຍໜຶ່ງ',
                ),
              ],
              cashierName: 'cash',
              queueNumber: 1,
            ),
          );
          // Every line is a bitmap (GS v 0) ...
          expect(_containsBytes(sent.bytes, const [0x1d, 0x76, 0x30]), isTrue);
          // ... and the job runs to the paper cut (GS V).
          expect(_containsBytes(sent.bytes, const [0x1d, 0x56]), isTrue);
        } finally {
          DisplayLanguage.code = oldLanguage;
        }
      });
    });

    testWidgets('the cash drawer pulse is sent and given time to arrive', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final service = PrinterService();
        final sent = await _capture((profile) async {
          await service.savePrinter(profile, setAsReceiptPrinter: true);
          await service.openCashDrawer();
        });
        expect(
          _containsBytes(sent.bytes, const [0x1b, 0x70, 0x00, 0x19, 0xfa]),
          isTrue,
        );
        expect(sent.open, greaterThanOrEqualTo(const Duration(milliseconds: 500)));
      });
    });

    testWidgets('a receipt renders on 80 mm paper', (tester) async {
      await tester.runAsync(() async {
        final bytes = await PrintRenderer(PaperSize.mm80).render(
          PrintLayouts.receipt(
            items: [CartItem(product: _product('Latte', 'ລາເຕ້', 35000))],
            subtotal: 35000,
            tax: 0,
            total: 35000,
            cashierName: 'cash',
          ),
        );
        expect(bytes.length, greaterThan(1000));
      });
    });
  });
}
