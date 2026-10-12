// Renders what receipts and kitchen tickets look like on paper, without a
// printer: the documents are drawn to ESC/POS bytes exactly as for a real
// printer, then the bytes are decoded back into PNGs (bitmap lines pasted
// as-is, the few printer-text rules drawn as text).
//
// Run:  flutter test tool_ticket_preview.dart --dart-define=OUT_DIR=/tmp
import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/services/printer_service.dart';
import 'package:ladolce/utils/localized_name.dart';

const _outDir = String.fromEnvironment('OUT_DIR', defaultValue: '.');

/// One printable chunk recovered from the ESC/POS stream.
class _Block {
  final img.Image? raster;
  final String? text;
  final bool doubleHeight;
  final int align; // 0 left, 1 center, 2 right
  _Block.raster(this.raster, this.align) : text = null, doubleHeight = false;
  _Block.text(this.text, this.align, this.doubleHeight) : raster = null;
}

List<_Block> _decodeEscPos(List<int> bytes) {
  final blocks = <_Block>[];
  final buffer = StringBuffer();
  var align = 0;
  var doubleHeight = false;
  var i = 0;

  void flushText() {
    final s = buffer.toString().trimRight();
    buffer.clear();
    if (s.isNotEmpty) blocks.add(_Block.text(s, align, doubleHeight));
  }

  while (i < bytes.length) {
    final b = bytes[i];

    // GS v 0 — raster bit image, the path every Lao string takes.
    if (b == 0x1d &&
        i + 7 < bytes.length &&
        bytes[i + 1] == 0x76 &&
        bytes[i + 2] == 0x30) {
      flushText();
      final widthBytes = bytes[i + 4] | (bytes[i + 5] << 8);
      final height = bytes[i + 6] | (bytes[i + 7] << 8);
      final start = i + 8;
      final size = widthBytes * height;
      if (start + size > bytes.length) break;
      final image = img.Image(widthBytes * 8, height);
      img.fill(image, img.getColor(255, 255, 255));
      for (var y = 0; y < height; y++) {
        for (var xb = 0; xb < widthBytes; xb++) {
          final byte = bytes[start + y * widthBytes + xb];
          for (var bit = 0; bit < 8; bit++) {
            // MSB first; a set bit means a fired dot.
            if ((byte >> (7 - bit)) & 1 == 1) {
              image.setPixelRgba(xb * 8 + bit, y, 0, 0, 0);
            }
          }
        }
      }
      blocks.add(_Block.raster(image, align));
      i = start + size;
      continue;
    }

    if (b == 0x1b && i + 1 < bytes.length) {
      final cmd = bytes[i + 1];
      if (cmd == 0x61 && i + 2 < bytes.length) {
        flushText();
        align = bytes[i + 2];
        i += 3;
        continue;
      }
      if (cmd == 0x21 && i + 2 < bytes.length) {
        flushText();
        doubleHeight = (bytes[i + 2] & 0x10) != 0;
        i += 3;
        continue;
      }
      if (cmd == 0x40) {
        i += 2;
        continue;
      }
      // ESC d/E/t/M/3/J and friends: one parameter byte.
      if (cmd == 0x64 ||
          cmd == 0x45 ||
          cmd == 0x74 ||
          cmd == 0x4d ||
          cmd == 0x33 ||
          cmd == 0x4a) {
        if (cmd == 0x64) flushText();
        i += 3;
        continue;
      }
      i += 2;
      continue;
    }

    if (b == 0x1d && i + 1 < bytes.length) {
      final cmd = bytes[i + 1];
      if (cmd == 0x21 && i + 2 < bytes.length) {
        flushText();
        doubleHeight = (bytes[i + 2] & 0x0f) != 0;
        i += 3;
        continue;
      }
      if (cmd == 0x56) {
        flushText();
        i += (i + 3 < bytes.length && bytes[i + 2] >= 65) ? 4 : 3;
        continue;
      }
      i += 3;
      continue;
    }

    if (b == 0x0a) {
      flushText();
      i += 1;
      continue;
    }
    if (b >= 0x20 && b < 0x7f) {
      buffer.writeCharCode(b);
    }
    i += 1;
  }
  flushText();
  return blocks;
}

img.Image _compose(List<_Block> blocks, int width) {
  const pad = 8;
  var height = pad * 2;
  for (final b in blocks) {
    height += b.raster != null
        ? b.raster!.height + 2
        : (b.doubleHeight ? 34 : 20);
  }

  final canvas = img.Image(width, height);
  img.fill(canvas, img.getColor(255, 255, 255));
  var y = pad;

  for (final b in blocks) {
    if (b.raster != null) {
      final src = b.raster!;
      final x = switch (b.align) {
        1 => ((width - src.width) / 2).round(),
        2 => width - src.width,
        _ => 0,
      };
      for (var sy = 0; sy < src.height; sy++) {
        for (var sx = 0; sx < src.width; sx++) {
          final dx = x + sx;
          if (dx < 0 || dx >= width) continue;
          if (img.getRed(src.getPixel(sx, sy)) < 128) {
            canvas.setPixelRgba(dx, y + sy, 0, 0, 0);
          }
        }
      }
      y += src.height + 2;
      continue;
    }
    img.drawString(
      canvas,
      img.arial_14,
      0,
      y,
      b.text!,
      color: img.getColor(0, 0, 0),
    );
    y += 20;
  }
  return canvas;
}

final _hot = Topping(
  id: 1,
  name: 'Hot',
  nameLo: 'ຮ້ອນ',
  groupId: 1,
  groupName: 'Type',
  groupSequence: 1,
);
final _sweet = Topping(
  id: 2,
  name: 'Sweet',
  nameLo: 'ຫວານ',
  groupId: 2,
  groupName: 'Taste',
  groupSequence: 2,
);
final _sizeM = Topping(
  id: 3,
  name: 'Size M',
  nameLo: 'ຂະໜາດ M',
  groupId: 3,
  groupName: 'Size',
  groupSequence: 3,
);

List<CartItem> _items() => [
  CartItem(
    product: Product(
      id: 1,
      name: 'Americano',
      nameLo: 'ອາເມລິກາໂນ',
      price: 30000,
      category: 'Coffee',
    ),
    quantity: 2,
    selectedToppings: [_sizeM, _sweet, _hot],
  ),
  CartItem(
    product: Product(
      id: 2,
      name: 'Cappuccino',
      nameLo: 'ກາປູຊີໂນ',
      price: 35000,
      category: 'Coffee',
    ),
    selectedToppings: [_hot],
    isFreePromo: true,
    promotionId: 1,
    kitchenNote: 'ບໍ່ໃສ່ນ້ຳຕານ',
  ),
  CartItem(
    product: Product(
      id: 3,
      name: 'Almond chocolate croissant',
      nameLo: 'ຄົວຊອງຊັອກໂກແລດອາມອນ',
      price: 46000,
      category: 'Bakery',
    ),
  ),
];

Future<void> _loadPrintFont() async {
  final loader = FontLoader(PrintRenderer.fontFamily);
  for (final f in ['Regular', 'Bold']) {
    final bytes = File('assets/fonts/NotoSerifLao-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _write(String name, List<PrintLine> lines) async {
  final bytes = await PrintRenderer(PaperSize.mm80).render(lines);
  final canvas = _compose(_decodeEscPos(bytes), PaperSize.mm80.width);
  final path = '$_outDir/$name.png';
  File(path).writeAsBytesSync(img.encodePng(canvas));
  // ignore: avoid_print
  print('WROTE $path');
}

void main() {
  testWidgets('render print previews', (tester) async {
    await _loadPrintFont();
    await tester.runAsync(() async {
      DisplayLanguage.code = 'lo';
      await _write(
        'receipt_lo',
        PrintLayouts.receipt(
          items: _items(),
          subtotal: 106000,
          tax: 0,
          total: 106000,
          cashierName: 'Sith Cashier',
          headerText: 'LaDolce\nLaDolce Main, Vientiane',
          payments: const [
            ReceiptPayment('Transfer (BCEL OnePay)', 100000),
            ReceiptPayment('Cash', 10000),
          ],
          changeAmount: 4000,
          customer: const ReceiptCustomer(
            name: 'test',
            pointsEarned: 10,
            totalPoints: 125,
          ),
        ),
      );
      await _write(
        'kitchen_ticket_lo',
        PrintLayouts.orderTicket(
          items: _items(),
          cashierName: 'Sith Cashier',
          queueNumber: 18,
        ),
      );
      DisplayLanguage.code = 'en';
      await _write(
        'bill_en',
        PrintLayouts.bill(
          items: _items(),
          subtotal: 106000,
          tax: 0,
          total: 106000,
          cashierName: 'Sith Cashier',
          ticketName: 'T 4',
          headerText: 'LaDolce\nLaDolce Main, Vientiane',
          queueNumber: 18,
        ),
      );
    });
  });
}
