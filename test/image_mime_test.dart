import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/utils/image_mime.dart';

/// Uploads must declare a truthful Content-Type. MultipartFile defaults to
/// application/octet-stream, Odoo stores that, and /web/image then serves the
/// attachment as a download instead of an image — the upload succeeds but the
/// picture never appears.
void main() {
  List<int> pad(List<int> sig, [int len = 32]) =>
      [...sig, ...List<int>.filled(len - sig.length, 0)];

  group('sniffImageMimeType', () {
    final cases = <String, (List<int>, String)>{
      'JPEG': ([0xFF, 0xD8, 0xFF, 0xE0], 'image/jpeg'),
      'PNG': ([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], 'image/png'),
      'GIF': ([0x47, 0x49, 0x46, 0x38, 0x39, 0x61], 'image/gif'),
      'BMP': ([0x42, 0x4D], 'image/bmp'),
      'TIFF LE': ([0x49, 0x49, 0x2A, 0x00], 'image/tiff'),
      'TIFF BE': ([0x4D, 0x4D, 0x00, 0x2A], 'image/tiff'),
      'ICO': ([0x00, 0x00, 0x01, 0x00], 'image/x-icon'),
    };

    cases.forEach((name, spec) {
      test('detects $name', () {
        expect(sniffImageMimeType(pad(spec.$1)), spec.$2);
      });
    });

    test('detects WEBP via the RIFF container', () {
      final webp = <int>[
        0x52, 0x49, 0x46, 0x46, // RIFF
        0, 0, 0, 0, // size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ];
      expect(sniffImageMimeType(pad(webp)), 'image/webp');
    });

    test('detects the ISO-BMFF family iPhones and Android produce', () {
      List<int> ftyp(String brand) => pad([
        0, 0, 0, 0x18,
        0x66, 0x74, 0x79, 0x70, // ftyp
        ...brand.codeUnits,
      ]);
      expect(sniffImageMimeType(ftyp('heic')), 'image/heic');
      expect(sniffImageMimeType(ftyp('mif1')), 'image/heif');
      expect(sniffImageMimeType(ftyp('avif')), 'image/avif');
    });

    test('returns null for something that is not an image', () {
      expect(sniffImageMimeType(pad('not an image'.codeUnits)), isNull);
      expect(sniffImageMimeType([1, 2, 3]), isNull, reason: 'too short');
    });
  });

  group('resolveImageMimeType', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('mime_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    Future<String> write(String name, List<int> bytes) async {
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes);
      return f.path;
    }

    test('trusts the bytes over a misleading extension', () async {
      // Pickers hand back names like image_picker_ABC.tmp, and an iOS ".jpg"
      // can still contain HEIC data.
      final path = await write('photo.jpg', pad([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
      expect(await resolveImageMimeType(path), 'image/png');
    });

    test('falls back to the extension when bytes are unrecognised', () async {
      final path = await write('photo.png', pad('zzzzzzzz'.codeUnits));
      expect(await resolveImageMimeType(path), 'image/png');
    });

    test('never yields a non-image type', () async {
      // Better a wrong image/* guess than octet-stream, which cannot render.
      final path = await write('mystery.bin', pad('zzzzzzzz'.codeUnits));
      final mime = await resolveImageMimeType(path);
      expect(mime.startsWith('image/'), isTrue);
    });

    test('survives a missing file', () async {
      final mime = await resolveImageMimeType('${dir.path}/nope.jpg');
      expect(mime, 'image/jpeg');
    });
  });

  group('imageFilenameFor', () {
    test('uses the extension matching the detected type', () {
      expect(imageFilenameFor('image/heic', prefix: 'order_9_proof'),
          'order_9_proof.heic');
      expect(imageFilenameFor('image/webp', prefix: 'chat_3'), 'chat_3.webp');
      expect(imageFilenameFor('image/png', prefix: 'p'), 'p.png');
    });

    test('falls back to jpg for an unknown type', () {
      expect(imageFilenameFor('application/octet-stream', prefix: 'p'), 'p.jpg');
    });
  });
}
