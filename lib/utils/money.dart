import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en_US');

/// Money as shown everywhere in the app and on paper: whole kip with
/// thousands separators, e.g. 90000.0 → "90,000". LAK has no coins, so the
/// ".00" was only noise. Put the currency in front yourself (₭ / LAK).
String money(num? value) => _moneyFormat.format((value ?? 0).round());

/// Reads an amount typed in a [MoneyInputFormatter] box ("90,000" → 90000).
double parseMoney(String text) =>
    double.tryParse(text.replaceAll(',', '').trim()) ?? 0.0;

/// Text box formatter for kip amounts: digits only, commas added while typing
/// ("90000" shows as "90,000"). Read the value back with [parseMoney].
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _moneyFormat.format(int.parse(digits));
    // Keep the cursor after the same number of digits as before the edit.
    final cursor = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBefore =
        newValue.text.substring(0, cursor).replaceAll(RegExp(r'[^0-9]'), '').length;
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < digitsBefore) {
      if (text[offset] != ',') seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
