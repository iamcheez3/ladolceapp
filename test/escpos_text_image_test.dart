import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ladolce/services/escpos_text_image.dart';

/// Guards the Lao printing path: ESC/POS encodes text with latin1, which throws
/// above U+00FF, so Lao must be detected and rasterised instead of encoded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter test has no network, so google_fonts cannot fetch Noto Sans Lao.
  // Inject the platform font instead: this exercises the same rasterise ->
  // encode path, just with different glyphs. Lao glyph coverage itself is
  // proven in-app, where the UI already renders Lao with this font stack.
  setUpAll(() {
    debugStyleResolver = (size, bold) async => TextStyle(
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: const Color(0xFF000000),
      height: 1.25,
    );
  });
  tearDownAll(() => debugStyleResolver = null);

  group('escPosNeedsImage', () {
    test('plain ASCII stays on the fast native-text path', () {
      expect(escPosNeedsImage('2x Americano'), isFalse);
      expect(escPosNeedsImage('LAK 45000.00'), isFalse);
      expect(escPosNeedsImage(''), isFalse);
    });

    test('Lao and other non-ASCII are routed to the raster path', () {
      expect(escPosNeedsImage('ກາເຟຮ້ອນ'), isTrue); // hot coffee
      expect(escPosNeedsImage('2x ຊາຂຽວ'), isTrue); // mixed latin + Lao
      expect(escPosNeedsImage('₭45,000'), isTrue); // kip sign, U+20AD
    });
  });

  group('rasteriser', () {
    test('renders a Lao line to a non-blank bitmap of the paper width', () async {
      final image = await renderEscPosLine(
        text: '2x ກາເຟນົມເຢັນ',
        widthDots: 558, // 80mm
        bold: true,
      );
      expect(image, isNotNull, reason: 'Lao line must produce a bitmap');
      expect(image!.width, 558);
      expect(image.height, greaterThan(8));

      // The bitmap must actually contain dark pixels, otherwise the printer
      // would emit a blank strip and the bug would look "fixed" but is not.
      var dark = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (img.getLuminance(image.getPixel(x, y)) < 128) dark++;
        }
      }
      expect(dark, greaterThan(0), reason: 'rendered line must have ink');

      File('build/lao_line.png').writeAsBytesSync(img.encodePng(image));
    });

    test('renders a two-column row with the price pinned right', () async {
      final image = await renderEscPosRow(
        left: '2x ກາເຟນົມເຢັນ ພິເສດ',
        right: 'LAK 45000.00',
        widthDots: 558,
        bold: true,
      );
      expect(image, isNotNull);
      expect(image!.width, 558);

      // Ink must appear in the right-hand quarter, proving the value is pinned
      // to the right edge rather than wrapped under the item name.
      var darkRight = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = (image.width * 3) ~/ 4; x < image.width; x++) {
          if (img.getLuminance(image.getPixel(x, y)) < 128) darkRight++;
        }
      }
      expect(darkRight, greaterThan(0), reason: 'price must render right-aligned');

      File('build/lao_row.png').writeAsBytesSync(img.encodePng(image));
    });

    test('empty text produces no bitmap', () async {
      expect(await renderEscPosLine(text: '   ', widthDots: 558), isNull);
    });
  });
}
