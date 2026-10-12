import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/services/printer_service.dart';
import 'package:ladolce/utils/localized_name.dart';

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

/// Binds a throwaway ESC/POS printer and returns every byte it was sent.
Future<List<int>> _capture(
  Future<void> Function(PrinterProfile profile) print,
) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final received = <int>[];
  final firstData = Completer<void>();
  server.listen((socket) {
    socket.listen((chunk) {
      received.addAll(chunk);
      if (!firstData.isCompleted) firstData.complete();
    });
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
    await firstData.future.timeout(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  } finally {
    await server.close();
  }
  return received;
}

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
        expect(labels.thankYou, 'Thank you!');
        expect(labels.orderTicket, 'Kitchen / Order Ticket');
        expect(labels.note, 'NOTE');
      } finally {
        DisplayLanguage.code = oldLanguage;
      }
    });
  });

  testWidgets('Lao receipt keeps English labels and a Lao menu name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final oldLanguage = DisplayLanguage.code;
      DisplayLanguage.code = 'lo';
      List<int> received;
      try {
        received = await _capture(
          (profile) => PrinterService().printReceiptToProfile(
            profile,
            cartItems: [
              CartItem(
                product: Product(
                  id: 1,
                  name: 'Honey coffee',
                  nameLo: 'ກາເຟນໍ້າເຜິ້ງ',
                  price: 40000,
                  category: 'Coffee',
                ),
              ),
            ],
            subtotal: 40000,
            tax: 0,
            total: 40000,
            cashierName: 'cash',
            subtotalRowLabel: 'Subtotal:',
            queueNumber: 3,
          ),
        );
      } finally {
        DisplayLanguage.code = oldLanguage;
      }

      expect(received.length, greaterThan(1000));

      // The Lao menu name can only reach paper through the bitmap path.
      final hasRasterCommand =
          _containsBytes(received, const [0x1d, 0x76, 0x30]) ||
          _containsBytes(received, const [0x1d, 0x28, 0x4c]);
      expect(hasRasterCommand, isTrue);

      final asciiPayload = latin1.decode(received, allowInvalid: true);
      // Labels are deliberately English on paper...
      expect(asciiPayload, contains('Thank you!'));
      expect(asciiPayload, contains('Please come again'));
      expect(asciiPayload, contains('Cashier: cash'));
      // ...only the menu name follows the app language.
      expect(asciiPayload, isNot(contains('Honey coffee')));
    });
  });

  testWidgets('Lao kitchen ticket keeps English labels and a Lao menu name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final oldLanguage = DisplayLanguage.code;
      DisplayLanguage.code = 'lo';
      List<int> received;
      try {
        received = await _capture(
          (profile) => PrinterService().printOrderTicketDirect(
            profile: profile,
            items: [
              CartItem(
                product: Product(
                  id: 1,
                  name: 'Almond chocolate croissant',
                  nameLo: 'ຄົວຊອງຊັອກໂກແລດອາມອນ',
                  price: 40000,
                  category: 'Bakery',
                ),
              ),
            ],
            cashierName: 'cash',
            queueNumber: 1,
          ),
        );
      } finally {
        DisplayLanguage.code = oldLanguage;
      }

      final asciiPayload = latin1.decode(received, allowInvalid: true);
      // Labels are deliberately English on paper...
      expect(asciiPayload, contains('Kitchen / Order Ticket'));
      expect(asciiPayload, contains('Printer: bar'));
      expect(asciiPayload, contains('Date:'));
      expect(asciiPayload, contains('Cashier: cash'));
      // ...only the menu name follows the app language.
      expect(asciiPayload, isNot(contains('Almond chocolate croissant')));
    });
  });

  testWidgets('English kitchen ticket prints the English menu name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final oldLanguage = DisplayLanguage.code;
      DisplayLanguage.code = 'en';
      List<int> received;
      try {
        received = await _capture(
          (profile) => PrinterService().printOrderTicketDirect(
            profile: profile,
            items: [
              CartItem(
                product: Product(
                  id: 1,
                  name: 'Almond chocolate croissant',
                  nameLo: 'ຄົວຊອງຊັອກໂກແລດອາມອນ',
                  price: 40000,
                  category: 'Bakery',
                ),
              ),
            ],
            cashierName: 'cash',
          ),
        );
      } finally {
        DisplayLanguage.code = oldLanguage;
      }

      final asciiPayload = latin1.decode(received, allowInvalid: true);
      expect(asciiPayload, contains('Almond chocolate croissant'));
      expect(asciiPayload, contains('Kitchen / Order Ticket'));
      expect(asciiPayload, contains('Cashier: cash'));
    });
  });
}
