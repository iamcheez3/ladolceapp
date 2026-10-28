// Prints the same kitchen order + receipt in several fonts so the shop can pick
// the most readable one. Not part of the test suite (lives in tool/).
//
//   FONT_DIR=<dir with the .ttf files> PRINT=1 flutter test tool/print_font_samples_test.dart
//
// PRINT=0 (default) only writes PNG previews to FONT_DIR/../samples.
// PRINT=1 also sends ESC/POS to PRINTER_HOST:PRINTER_PORT (default the
// laptop's Printer Bridge on 127.0.0.1:9100).
import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/services/escpos_text_image.dart';
import 'package:ladolce/services/printer_service.dart';

const _dots = 558; // 80mm, same as PrinterService._dotsFor
const _normal = 26.0; // PrinterService raster sizes
const _large = 40.0;
const _queue = 48.0; // native 2x2 queue number is ~48 dots tall

final _env = Platform.environment;
final _fontDir = _env['FONT_DIR'] ?? 'fonts';
final _print = _env['PRINT'] == '1';
final _host = _env['PRINTER_HOST'] ?? '127.0.0.1';
final _port = int.tryParse(_env['PRINTER_PORT'] ?? '') ?? 9100;

class _Font {
  const _Font(this.no, this.label, this.family, this.files);
  final String no;
  final String label;
  final String family;
  final List<String> files;
}

const _fonts = [
  _Font('2', 'Noto Sans Lao', 'NotoSansLao', ['NotoSansLao-Regular.ttf', 'NotoSansLao-Bold.ttf']),
  _Font('3', 'Noto Sans Lao Looped', 'NotoSansLaoLooped',
      ['NotoSansLaoLooped-Regular.ttf', 'NotoSansLaoLooped-Bold.ttf']),
  _Font('4', 'Noto Serif Lao', 'NotoSerifLao', ['NotoSerifLao-Regular.ttf', 'NotoSerifLao-Bold.ttf']),
  _Font('5', 'Phetsarath OT', 'PhetsarathOT', ['PhetsarathOT-Regular.ttf', 'PhetsarathOT-Bold.ttf']),
  // Saysettha OT left out: it drops tone marks stacked over vowels
  // (ບໍ່ → ບໍ, ນ້ຳ → ນຳ), which changes the words.
];

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final b = File('$_fontDir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes)));
  }
  await loader.load();
}

void _useFont(String family) {
  debugStyleResolver = (size, bold) async => TextStyle(
        fontFamily: family,
        fontFamilyFallback: const ['NotoSans'],
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: Colors.black,
        height: 1.25,
      );
}

// Real menu items (from live open tickets) plus one product with no Lao name.
final _americano = Product(id: 61, name: 'Americano', nameLo: 'ອາເມລິກາໂນ', price: 32000, category: 'Coffee');
final _banoffee = Product(id: 490, name: 'Banoffee', nameLo: 'ບານ໋ອບຟີ້', price: 40000, category: 'Cake');
final _croissant = Product(
    id: 479, name: 'Almon choccolate croissant', nameLo: 'ຄົວຊອງອາວມ້ອນຊ໋ອກໂກແລັດ', price: 46000, category: 'Bakery');
final _latte = Product(id: 1, name: 'Iced Latte', price: 35000, category: 'Coffee');
final _cream = Topping(id: 532, name: 'ເພີ່ມຄີຣມຊີດ', extraPrice: 20000);

List<CartItem> _items() => [
      CartItem(product: _americano, quantity: 2, kitchenNote: 'ຫວານໜ້ອຍ ບໍ່ໃສ່ນ້ຳກ້ອນ'),
      CartItem(product: _banoffee, selectedToppings: [_cream]),
      CartItem(product: _latte, kitchenNote: 'less ice'),
      CartItem(product: _croissant),
    ];

/// One strip: ESC/POS bytes for the printer plus a PNG preview of the same.
class _Strip {
  _Strip(this.gen);
  final Generator gen;
  final bytes = <int>[];
  final images = <img.Image>[];

  Future<void> line(String text, {bool bold = false, double size = _normal, TextAlign align = TextAlign.left}) async {
    final im = await renderEscPosLine(text: text, widthDots: _dots, bold: bold, fontSize: size, align: align);
    if (im == null) return;
    bytes.addAll(gen.imageRaster(im));
    images.add(im);
  }

  Future<void> row(String left, String right, {bool bold = false, double size = _normal}) async {
    final im = await renderEscPosRow(left: left, right: right, widthDots: _dots, bold: bold, fontSize: size);
    if (im == null) return;
    bytes.addAll(gen.imageRaster(im));
    images.add(im);
  }

  void hr() {
    bytes.addAll(gen.hr());
    images.add(img.fillRect(img.Image(_dots, 14)..fill(0xFFFFFFFF), 0, 6, _dots - 1, 7, 0xFF000000));
  }

  void gap(int lines) {
    bytes.addAll(gen.feed(lines));
    images.add(img.Image(_dots, 24 * lines)..fill(0xFFFFFFFF));
  }

  img.Image preview() {
    final h = images.fold<int>(0, (s, i) => s + i.height);
    final out = img.Image(_dots, h)..fill(0xFFFFFFFF);
    var y = 0;
    for (final i in images) {
      img.copyInto(out, i, dstX: 0, dstY: y, blend: false);
      y += i.height;
    }
    return out;
  }
}

const _date = 'Date: 2026-10-10 14:05:33';

/// Mirrors PrinterService._printOrderTicketToProfile, every line in [font].
Future<void> _order(_Strip s) async {
  await s.line('Kitchen / Order Ticket', bold: true, size: _large, align: TextAlign.center);
  await s.line('Printer: Kitchen', align: TextAlign.center);
  s.hr();
  await s.line('#012', bold: true, size: _queue, align: TextAlign.center);
  s.hr();
  await s.line(_date);
  await s.line('Cashier: Sith');
  s.hr();
  for (final i in _items()) {
    await s.line('${i.quantity}x ${i.product.displayName}', bold: true, size: _large);
    for (final t in i.selectedToppings) {
      await s.line('  + ${t.name}');
    }
    if (i.kitchenNote.isNotEmpty) await s.line('  NOTE: ${i.kitchenNote}', bold: true);
    s.gap(1);
  }
}

/// Mirrors PrinterService._printReceiptToProfile, every line in [font].
Future<void> _receipt(_Strip s) async {
  final items = _items();
  final total = items.fold<double>(0, (t, i) => t + i.totalPrice);
  await s.line('LaDolce', bold: true, size: _queue, align: TextAlign.center);
  await s.line('Point of Sale', align: TextAlign.center);
  await s.line('Printer: Counter', align: TextAlign.center);
  s.hr();
  await s.line('#012', bold: true, size: _queue, align: TextAlign.center);
  s.hr();
  await s.line(_date);
  await s.line('Cashier: Sith');
  s.hr();
  for (final i in items) {
    await s.row('${i.quantity}x ${i.product.displayName}', 'LAK${i.totalPrice.toStringAsFixed(2)}', bold: true);
  }
  s.hr();
  await s.row('TOTAL:', 'LAK${total.toStringAsFixed(2)}', bold: true, size: _large);
  s.gap(1);
  await s.line('Thank you!', bold: true, align: TextAlign.center);
  await s.line('Please come again', align: TextAlign.center);
  await s.line('ຂອບໃຈທີ່ມາອຸດໜູນ', align: TextAlign.center);
}

Future<void> _send(List<int> bytes) async {
  final socket = await Socket.connect(_host, _port, timeout: const Duration(seconds: 5));
  socket.add(bytes);
  await socket.flush();
  await socket.close();
  socket.destroy();
  await Future<void>.delayed(const Duration(seconds: 2)); // let the bridge spool it
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Product.useLaoNames = true; // Lao staff run the app in Lao

  test('font samples', () async {
    final outDir = Directory('$_fontDir/../samples')..createSync(recursive: true);
    final gen = Generator(PaperSize.mm80, await CapabilityProfile.load());
    await _load('NotoSans', ['NotoSans-Regular.ttf', 'NotoSans-Bold.ttf']);

    // 1 = what the app prints today: printer font for English, Noto Sans Lao
    // image for Lao, through the real PrinterService code.
    if (_print) {
      await _load('NotoSansLao', _fonts.first.files);
      _useFont('NotoSansLao');
      final banner = _Strip(gen);
      await banner.line('FONT 1', bold: true, size: _queue, align: TextAlign.center);
      await banner.line('CURRENT (today)', bold: true, align: TextAlign.center);
      banner.gap(1);
      await _send(gen.reset() + banner.bytes);
      final service = PrinterService();
      final kitchen = PrinterProfile(id: 'k', name: 'Kitchen', ip: _host, port: _port, printOrders: true);
      final counter = PrinterProfile(id: 'c', name: 'Counter', ip: _host, port: _port);
      expect(await service.printOrderTicketDirect(
          profile: kitchen, items: _items(), cashierName: 'Sith', queueNumber: 12), isTrue);
      await Future<void>.delayed(const Duration(seconds: 2));
      final items = _items();
      final total = items.fold<double>(0, (t, i) => t + i.totalPrice);
      expect(await service.printReceiptToProfile(counter,
          cartItems: items, subtotal: total, tax: 0, total: total, cashierName: 'Sith', queueNumber: 12), isTrue);
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    for (final f in _fonts) {
      await _load(f.family, f.files);
      _useFont(f.family);
      final s = _Strip(gen);
      await s.line('FONT ${f.no}', bold: true, size: _queue, align: TextAlign.center);
      await s.line(f.label, bold: true, align: TextAlign.center);
      s.hr();
      await _order(s);
      s.hr();
      s.gap(1);
      await _receipt(s);
      s.gap(3);
      File('${outDir.path}/font_${f.no}_${f.family}.png').writeAsBytesSync(img.encodePng(s.preview()));
      if (_print) await _send(gen.reset() + s.bytes + gen.cut());
    }
    debugStyleResolver = null;
  }, timeout: const Timeout(Duration(minutes: 5)));

  // The shipped result: real PrinterService code, the production font resolver
  // (no override) and the font files bundled in assets/fonts.
  test('app print', () async {
    await _loadBundled();
    debugStyleResolver = null;
    final service = PrinterService();
    final kitchen = PrinterProfile(id: 'k', name: 'Kitchen', ip: _host, port: _port, printOrders: true);
    final counter = PrinterProfile(id: 'c', name: 'Counter', ip: _host, port: _port);
    expect(await service.printOrderTicketDirect(
        profile: kitchen, items: _items(), cashierName: 'Sith', queueNumber: 12), isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
    final items = _items();
    final total = items.fold<double>(0, (t, i) => t + i.totalPrice);
    expect(await service.printReceiptToProfile(counter,
        cartItems: items, subtotal: total, tax: 0, total: total, cashierName: 'Sith', queueNumber: 12), isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
  });
}

Future<void> _loadBundled() async {
  final loader = FontLoader(printFontFamily);
  for (final f in ['assets/fonts/NotoSerifLao-Regular.ttf', 'assets/fonts/NotoSerifLao-Bold.ttf']) {
    final b = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.lengthInBytes)));
  }
  await loader.load();
}
