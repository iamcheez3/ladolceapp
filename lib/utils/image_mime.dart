import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart' as mime_pkg;

/// Works out what an image file actually *is*, so uploads carry a truthful
/// Content-Type.
///
/// `MultipartFile.fromPath` defaults to `application/octet-stream`, and Odoo
/// stores whatever the client claims. `/web/image` then does:
///
/// ```python
/// if not stream.mimetype.startswith('image/'):
///     stream.mimetype = 'application/octet-stream'
/// ```
///
/// so the bytes come back as a download instead of an image, and the proof
/// looks missing even though it uploaded fine. Sending the real type fixes
/// every viewer at once.
///
/// Detection reads the file's magic bytes rather than trusting the extension,
/// because pickers hand back names like `image_picker_ABC123.tmp`, and an iOS
/// `.jpg` can still hold HEIC data.

/// Magic-byte signatures for the formats a phone or gallery can realistically
/// produce. Order matters only in that the ISO-BMFF family shares a prefix.
const _jpegExt = 'jpg';

String _extFor(String mimeType) => switch (mimeType) {
  'image/jpeg' => _jpegExt,
  'image/png' => 'png',
  'image/gif' => 'gif',
  'image/webp' => 'webp',
  'image/bmp' => 'bmp',
  'image/tiff' => 'tiff',
  'image/heic' => 'heic',
  'image/heif' => 'heif',
  'image/avif' => 'avif',
  'image/x-icon' => 'ico',
  'image/svg+xml' => 'svg',
  _ => _jpegExt,
};

bool _startsWith(List<int> b, List<int> sig, [int offset = 0]) {
  if (b.length < offset + sig.length) return false;
  for (var i = 0; i < sig.length; i++) {
    if (b[offset + i] != sig[i]) return false;
  }
  return true;
}

/// Reads the leading bytes of [header] and returns an `image/*` type, or null
/// when the content is not a recognised image.
String? sniffImageMimeType(List<int> header) {
  if (header.length < 12) return null;

  if (_startsWith(header, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (_startsWith(header, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (_startsWith(header, [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
  if (_startsWith(header, [0x42, 0x4D])) return 'image/bmp';
  // TIFF, little- and big-endian.
  if (_startsWith(header, [0x49, 0x49, 0x2A, 0x00]) ||
      _startsWith(header, [0x4D, 0x4D, 0x00, 0x2A])) {
    return 'image/tiff';
  }
  if (_startsWith(header, [0x00, 0x00, 0x01, 0x00])) return 'image/x-icon';
  // RIFF....WEBP
  if (_startsWith(header, [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(header, [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  // ISO-BMFF: "....ftyp<brand>" — HEIC/HEIF from iOS, AVIF from newer Android.
  if (_startsWith(header, [0x66, 0x74, 0x79, 0x70], 4)) {
    final brand = String.fromCharCodes(header.sublist(8, 12)).toLowerCase();
    return switch (brand) {
      'avif' || 'avis' => 'image/avif',
      'heic' || 'heix' || 'hevc' || 'hevx' => 'image/heic',
      'mif1' || 'msf1' || 'heim' || 'heis' => 'image/heif',
      _ => null,
    };
  }
  return null;
}

/// Best-effort image type for [path]: magic bytes first, then the extension.
///
/// Falls back to `image/jpeg` rather than null, because every caller is
/// uploading something the user picked from an image picker — labelling it
/// `image/jpeg` still renders far more reliably than `application/octet-stream`.
Future<String> resolveImageMimeType(String path) async {
  try {
    final file = File(path);
    final length = await file.length();
    final header = await file
        .openRead(0, length < 32 ? length : 32)
        .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    final sniffed = sniffImageMimeType(header);
    if (sniffed != null) return sniffed;
  } catch (_) {
    // Unreadable header: fall through to the extension.
  }
  final byExtension = mime_pkg.lookupMimeType(path);
  if (byExtension != null && byExtension.startsWith('image/')) {
    return byExtension;
  }
  return 'image/jpeg';
}

/// Content-Type to attach to a multipart image part.
Future<MediaType> resolveImageMediaType(String path) async =>
    MediaType.parse(await resolveImageMimeType(path));

/// A filename whose extension matches the real content, so the attachment is
/// stored and downloaded under a sensible name.
String imageFilenameFor(String mimeType, {String prefix = 'upload'}) =>
    '$prefix.${_extFor(mimeType)}';
