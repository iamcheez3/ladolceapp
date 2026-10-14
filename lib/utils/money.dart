import 'package:intl/intl.dart';

// en_US so the separators stay "70,000.00" whatever the app language is.
final NumberFormat _twoDecimals = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _noDecimals = NumberFormat('#,##0', 'en_US');

/// Money as shown on screen, thousands separated: `₭70,000.00`, or
/// `₭70,000` with [decimals] 0. [symbol] replaces the `₭` (e.g. `'LAK '`, or
/// `''` for a number that goes into a translated sentence).
///
/// Printed receipts keep their own format (`PrintLayouts.money`).
String formatKip(num? value, {int decimals = 2, String symbol = '₭'}) {
  assert(decimals == 0 || decimals == 2);
  final format = decimals == 0 ? _noDecimals : _twoDecimals;
  return '$symbol${format.format(value ?? 0)}';
}
