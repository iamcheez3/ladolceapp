import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/services/escpos_text_image.dart';
import 'package:ladolce/services/printer_service.dart';

/// A kitchen note typed in Lao used to throw inside printer.text (latin1), so
/// the grouped kitchen ticket stopped mid-job and the save reported a failure.
/// A loopback socket stands in for the kitchen printer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // No network under flutter test; see escpos_text_image_test.dart.
  setUpAll(() {
    debugStyleResolver = (size, bold) async => TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: const Color(0xFF000000),
      height: 1.25,
    );
  });
  tearDownAll(() => debugStyleResolver = null);

  Future<bool> printWithNote(String note, {required bool single}) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) => socket.listen((_) {}, onError: (_) {}));
    try {
      return await PrinterService().printOrderTicketDirect(
        profile: PrinterProfile(
          id: 'kitchen',
          name: 'Kitchen',
          ip: '127.0.0.1',
          port: server.port,
          printOrders: true,
          singleItemPerTicket: single,
        ),
        items: [
          CartItem(
            product: Product(id: 1, name: 'Iced Latte', price: 30000, category: 'Drinks'),
            quantity: 2,
            kitchenNote: note,
          ),
        ],
        cashierName: 'Test',
      );
    } finally {
      await server.close();
    }
  }

  test('grouped kitchen ticket prints a Lao note', () async {
    expect(await printWithNote('ຫວານໜ້ອຍ ບໍ່ໃສ່ນ້ຳກ້ອນ', single: false), isTrue);
  });

  test('single-item kitchen ticket prints a Lao note', () async {
    expect(await printWithNote('ຫວານໜ້ອຍ', single: true), isTrue);
  });

  test('ASCII note still prints', () async {
    expect(await printWithNote('less sugar', single: false), isTrue);
  });

  test('receipt prints every line in the print font, Lao names included', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final received = <int>[];
    server.listen((socket) => socket.listen(received.addAll, onError: (_) {}));
    try {
      final ok = await PrinterService().printReceiptToProfile(
        PrinterProfile(id: 'counter', name: 'Counter', ip: '127.0.0.1', port: server.port),
        cartItems: [
          CartItem(
            product: Product(id: 1, name: 'Americano', nameLo: 'ອາເມລິກາໂນ', price: 32000, category: 'Coffee'),
            quantity: 2,
          ),
        ],
        subtotal: 64000,
        tax: 0,
        total: 64000,
        cashierName: 'Test',
        discountAmount: 5000,
        queueNumber: 12,
      );
      expect(ok, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      // No plain ESC/POS text should remain: the date and totals are ASCII, so
      // finding them as bytes would mean a line skipped the print font.
      final ascii = String.fromCharCodes(received.where((b) => b >= 0x20 && b < 0x7F));
      expect(ascii.contains('TOTAL'), isFalse);
      expect(ascii.contains('Cashier'), isFalse);
    } finally {
      await server.close();
    }
  });
}
