// Renders what a kitchen ticket would look like on paper, without a printer.
//
// The app talks ESC/POS over a socket, so this binds a local socket, prints a
// ticket into it, then decodes the captured bytes back into a PNG: raster
// blocks (all Lao text) are pasted as-is and ASCII runs are drawn as text.
//
// Run:  flutter test tool_ticket_preview.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/services/printer_service.dart';
import 'package:ladolce/utils/localized_name.dart';

const _outDir = String.fromEnvironment('OUT_DIR', defaultValue: '.');
const _menuFile = String.fromEnvironment('MENU_FILE');
const _paperWidthMm = 58;
const _canvasWidth = 384;

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

img.Image _compose(List<_Block> blocks) {
  const pad = 8;
  var height = pad * 2;
  for (final b in blocks) {
    height += b.raster != null
        ? b.raster!.height + 2
        : (b.doubleHeight ? 34 : 20);
  }

  final canvas = img.Image(_canvasWidth, height);
  img.fill(canvas, img.getColor(255, 255, 255));
  var y = pad;

  for (final b in blocks) {
    if (b.raster != null) {
      final src = b.raster!;
      final x = switch (b.align) {
        1 => ((_canvasWidth - src.width) / 2).round(),
        2 => _canvasWidth - src.width,
        _ => 0,
      };
      for (var sy = 0; sy < src.height; sy++) {
        for (var sx = 0; sx < src.width; sx++) {
          final dx = x + sx;
          if (dx < 0 || dx >= _canvasWidth) continue;
          if (img.getRed(src.getPixel(sx, sy)) < 128) {
            canvas.setPixelRgba(dx, y + sy, 0, 0, 0);
          }
        }
      }
      y += src.height + 2;
      continue;
    }

    final font = b.doubleHeight ? img.arial_24 : img.arial_14;
    final text = b.text!;
    final approxWidth = text.length * (b.doubleHeight ? 13 : 8);
    final x = switch (b.align) {
      1 => ((_canvasWidth - approxWidth) / 2).round().clamp(0, _canvasWidth),
      2 => (_canvasWidth - approxWidth).clamp(0, _canvasWidth),
      _ => 0,
    };
    img.drawString(canvas, font, x, y, text, color: img.getColor(0, 0, 0));
    y += b.doubleHeight ? 34 : 20;
  }
  return canvas;
}

/// Reads the menu to print from `MENU_FILE`, falling back to a small sample.
///
/// Each entry: {"name": "...", "name_lo": "...", "qty": 1, "note": "",
/// "toppings": ["..."]} — only `name` is required.
List<CartItem> _menuItems() {
  var entries = const <Map<String, dynamic>>[
    {'name': 'Almond chocolate croissant', 'name_lo': 'ຄົວຊອງຊັອກໂກແລດອາມອນ'},
    {
      'name': 'Honey coffee',
      'name_lo': 'ກາເຟນໍ້າເຜິ້ງ',
      'qty': 2,
      'note': 'ຫວານໜ້ອຍ',
      'toppings': ['Add cream cheese'],
    },
    // No Lao name saved, to show the English fallback.
    {'name': 'Butter croissant'},
  ];

  if (_menuFile.isNotEmpty) {
    final file = File(_menuFile);
    if (file.existsSync()) {
      final parsed = jsonDecode(file.readAsStringSync()) as List;
      entries = parsed.cast<Map<String, dynamic>>().toList(growable: false);
      // ignore: avoid_print
      print('MENU: $_menuFile (${entries.length} items)');
    } else {
      // ignore: avoid_print
      print('MENU: $_menuFile not found — using the built-in sample');
    }
  } else {
    // ignore: avoid_print
    print('MENU: built-in sample (pass --dart-define=MENU_FILE=... to change)');
  }

  var id = 1;
  return entries.map((e) {
    final toppings = (e['toppings'] as List?) ?? const [];
    return CartItem(
      product: Product(
        id: id++,
        name: (e['name'] ?? 'Item').toString(),
        nameLo: (e['name_lo'] ?? '').toString(),
        price: 0,
        category: 'Preview',
      ),
      quantity: (e['qty'] as num?)?.toInt() ?? 1,
      kitchenNote: (e['note'] ?? '').toString(),
      selectedToppings: [
        for (final t in toppings) Topping(id: id++, name: t.toString()),
      ],
    );
  }).toList();
}

Future<List<int>> _captureTicket({required String languageCode}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final received = <int>[];
  final firstData = Completer<void>();
  server.listen((socket) {
    socket.listen((chunk) {
      received.addAll(chunk);
      if (!firstData.isCompleted) firstData.complete();
    });
  });

  final oldLanguage = DisplayLanguage.code;
  DisplayLanguage.code = languageCode;
  try {
    await PrinterService().printOrderTicketDirect(
      profile: PrinterProfile(
        id: 'virtual',
        name: 'bar',
        ip: InternetAddress.loopbackIPv4.address,
        port: server.port,
        paperWidthMm: _paperWidthMm,
      ),
      items: _menuItems(),
      cashierName: languageCode == 'lo' ? 'ນ້ອຍ' : 'cash',
      queueNumber: 1,
    );
    await firstData.future.timeout(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  } finally {
    DisplayLanguage.code = oldLanguage;
    await server.close();
  }
  return received;
}

/// `flutter test` runs headless with no system fonts, so Lao would rasterise
/// as tofu boxes here even when a device renders it correctly. Loading a real
/// Lao face under the family name the printer asks for makes this preview
/// represent a device that has the font (as Android does).
Future<bool> _loadLaoFont() async {
  const candidates = [
    '/System/Library/Fonts/Supplemental/Lao Sangam MN.ttf',
    '/System/Library/Fonts/Supplemental/NotoSansLao-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansLao-Regular.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Noto Sans Lao')
      ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
    // ignore: avoid_print
    print('LAO FONT: $path');
    return true;
  }
  // ignore: avoid_print
  print('LAO FONT: none found — Lao will render as tofu boxes');
  return false;
}

void main() {
  testWidgets('render kitchen ticket previews', (tester) async {
    await _loadLaoFont();
    await tester.runAsync(() async {
      for (final lang in ['lo', 'en']) {
        final bytes = await _captureTicket(languageCode: lang);
        final canvas = _compose(_decodeEscPos(bytes));
        final path = '$_outDir/kitchen_ticket_$lang.png';
        File(path).writeAsBytesSync(img.encodePng(canvas));
        // ignore: avoid_print
        print('WROTE $path  (${bytes.length} bytes captured)');
      }
    });
  });
}
