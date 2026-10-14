import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// en_US so the separators stay "70,000.00" whatever the app language is.
final NumberFormat _twoDecimals = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _noDecimals = NumberFormat('#,##0', 'en_US');

/// Money as shown on screen, thousands separated: `₭70,000.00`, or
/// `₭70,000` with [decimals] 0. [symbol] replaces the `₭` (e.g. `'LAK '`, or
/// `''` for a number that goes into a translated sentence or a text field).
///
/// Printed receipts keep their own format (`PrintLayouts.money`).
String formatKip(num? value, {int decimals = 2, String symbol = '₭'}) {
  assert(decimals == 0 || decimals == 2);
  final format = decimals == 0 ? _noDecimals : _twoDecimals;
  return '$symbol${format.format(value ?? 0)}';
}

/// Puts thousands separators in a money field while it is typed:
/// `100000` shows as `100,000`. Up to two decimals are kept. Read the field
/// with the commas removed (`text.replaceAll(',', '')`).
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var caret = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : text.length;

    // Backspace right after a comma removes the digit before it, not just the
    // comma (which would come straight back).
    final old = oldValue.text;
    if (old.length - text.length == 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.extentOffset == caret + 1 &&
        caret < old.length &&
        old[caret] == ',' &&
        caret > 0) {
      text = text.substring(0, caret - 1) + text.substring(caret);
      caret -= 1;
    }

    // Keep the digits, the first '.', and two decimals; count how many of the
    // kept characters sit before the caret.
    final kept = StringBuffer();
    var keptBeforeCaret = 0;
    var hasDot = false;
    var decimals = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      final isDigit = c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
      var keep = false;
      if (isDigit) {
        keep = !hasDot || decimals < 2;
        if (keep && hasDot) decimals++;
      } else if (c == '.' && !hasDot) {
        keep = hasDot = true;
      }
      if (!keep) continue;
      kept.write(c);
      if (i < caret) keptBeforeCaret++;
    }

    final raw = kept.toString();
    if (raw.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final dot = raw.indexOf('.');
    var whole = dot < 0 ? raw : raw.substring(0, dot);
    final fraction = dot < 0 ? '' : raw.substring(dot);

    // Drop leading zeros ("007" -> "7"), keeping one before a '.'.
    var zeros = 0;
    while (zeros < whole.length - 1 && whole[zeros] == '0') {
      zeros++;
    }
    whole = whole.substring(zeros);
    keptBeforeCaret = (keptBeforeCaret - zeros).clamp(0, raw.length);
    if (whole.isEmpty) {
      // ".5" -> "0.5": the added zero sits before the caret.
      whole = '0';
      if (keptBeforeCaret > 0) keptBeforeCaret++;
    }
    // Far beyond any bill; refuse rather than overflow.
    if (whole.length > 15) return oldValue;

    final grouped = _noDecimals.format(int.parse(whole));
    final formatted = '$grouped$fraction';

    // Caret: after the same number of kept characters, skipping commas.
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < keptBeforeCaret) {
      if (formatted[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
