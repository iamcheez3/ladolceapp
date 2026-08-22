import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

/// Rasterises text so ESC/POS printers can output scripts they cannot encode.
///
/// `esc_pos_utils` sends text through `latin1.encode`, which throws a
/// `FormatException` on any code unit above 0xFF. Lao sits at U+0E80..U+0EFF,
/// so a single Lao product name used to abort the whole receipt. Thermal
/// printers also carry no Lao glyphs in their code pages, so even switching
/// code page would print garbage. Drawing the line with Flutter's text engine
/// and sending it as a bitmap is the only way the characters actually appear.
///
/// ASCII lines are deliberately left alone: they stay crisp printer text and
/// avoid the much larger raster payload.

/// True when [s] holds anything outside printable ASCII, i.e. anything the
/// ESC/POS encoder would mangle or reject.
bool escPosNeedsImage(String s) {
  for (final unit in s.codeUnits) {
    if (unit > 0x7E) return true;
  }
  return false;
}

/// Overridable font resolver. `google_fonts` fires a network fetch and, on
/// failure, leaks the error through a `.then` it never guards — harmless in the
/// app (the fallback below still runs) but fatal under `flutter test`, which has
/// no network. Tests inject a plain style so the raster pipeline can be verified
/// offline and deterministically.
@visibleForTesting
Future<TextStyle> Function(double fontSize, bool bold)? debugStyleResolver;

/// Resolves the font used for rasterised lines.
///
/// Noto Sans Lao covers Lao and Latin, and the app already loads it for the UI
/// whenever the locale is `lo`, so it is normally warm in the google_fonts
/// cache by the time a receipt prints. If it cannot be resolved — a shop that
/// is offline with a cold cache — this falls back to the platform font rather
/// than throwing, because a degraded receipt beats a failed print.
Future<TextStyle> _resolveStyle(double fontSize, bool bold) async {
  final override = debugStyleResolver;
  if (override != null) return override(fontSize, bold);
  final weight = bold ? FontWeight.w700 : FontWeight.w400;
  final fallback = TextStyle(
    fontSize: fontSize,
    fontWeight: weight,
    color: Colors.black,
    height: 1.25,
  );
  try {
    final style = GoogleFonts.notoSansLao(
      fontSize: fontSize,
      fontWeight: weight,
      color: Colors.black,
      height: 1.25,
    );
    // Awaited so a download failure surfaces here, inside the guard, instead of
    // escaping as an unhandled async error mid-print.
    await GoogleFonts.pendingFonts([style]);
    return style;
  } catch (_) {
    return fallback;
  }
}

ui.Paragraph _buildParagraph(
  String text,
  TextStyle style,
  double maxWidth,
  TextAlign align,
) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textAlign: align,
            fontFamily: style.fontFamily,
            fontSize: style.fontSize,
            fontWeight: style.fontWeight,
            height: style.height,
          ),
        )
        ..pushStyle(
          ui.TextStyle(
            color: Colors.black,
            fontFamily: style.fontFamily,
            fontSize: style.fontSize,
            fontWeight: style.fontWeight,
            fontFamilyFallback: style.fontFamilyFallback,
          ),
        )
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
}

Future<img.Image?> _rasterise(
  double width,
  double height,
  void Function(Canvas canvas) paint,
) async {
  if (width <= 0 || height <= 0) return null;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // The ESC/POS rasteriser inverts luminance, so the ground must be white.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );
  paint(canvas);
  final picture = recorder.endRecording();
  final uiImage = await picture.toImage(width.ceil(), height.ceil());
  try {
    final data = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return img.decodePng(data.buffer.asUint8List());
  } finally {
    uiImage.dispose();
    picture.dispose();
  }
}

/// Renders one full-width line, wrapping when it exceeds the paper width.
/// Returns null if the text is blank or rendering fails; callers fall back to
/// sanitised ASCII so a print is never aborted.
Future<img.Image?> renderEscPosLine({
  required String text,
  required int widthDots,
  bool bold = false,
  double fontSize = 26,
  TextAlign align = TextAlign.left,
}) async {
  final trimmed = text.trimRight();
  if (trimmed.isEmpty) return null;
  try {
    final style = await _resolveStyle(fontSize, bold);
    final w = widthDots.toDouble();
    final paragraph = _buildParagraph(trimmed, style, w, align);
    return await _rasterise(
      w,
      paragraph.height + 4,
      (canvas) => canvas.drawParagraph(paragraph, const Offset(0, 2)),
    );
  } catch (_) {
    return null;
  }
}

/// Renders a two-column line: [left] flows from the margin, [right] is pinned
/// to the right edge. Item rows share one bitmap so the name and its price stay
/// on the same baseline; only the name is ever non-ASCII.
Future<img.Image?> renderEscPosRow({
  required String left,
  required String right,
  required int widthDots,
  bool bold = false,
  double fontSize = 26,
}) async {
  if (left.trim().isEmpty && right.trim().isEmpty) return null;
  try {
    final style = await _resolveStyle(fontSize, bold);
    final w = widthDots.toDouble();

    // maxIntrinsicWidth is what the value actually needs; cap it so a long
    // price can never squeeze the item name out entirely.
    final rightWidth = right.isEmpty
        ? 0.0
        : _buildParagraph(
            right,
            style,
            w,
            TextAlign.right,
          ).maxIntrinsicWidth.clamp(0.0, w * 0.5);
    final gap = right.isEmpty ? 0.0 : 8.0;
    final leftWidth = (w - rightWidth - gap).clamp(1.0, w);

    final leftPara = _buildParagraph(left, style, leftWidth, TextAlign.left);
    final rightPara = right.isEmpty
        ? null
        : _buildParagraph(right, style, rightWidth, TextAlign.right);
    final height = rightPara == null || leftPara.height >= rightPara.height
        ? leftPara.height
        : rightPara.height;

    return await _rasterise(w, height + 4, (canvas) {
      canvas.drawParagraph(leftPara, const Offset(0, 2));
      if (rightPara != null) {
        canvas.drawParagraph(rightPara, Offset(w - rightWidth, 2));
      }
    });
  } catch (_) {
    return null;
  }
}
