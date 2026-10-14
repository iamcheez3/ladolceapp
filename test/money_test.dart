import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ladolce/utils/money.dart';

void main() {
  test('thousands are separated with commas', () {
    expect(formatKip(70000), '₭70,000.00');
    expect(formatKip(100000), '₭100,000.00');
    expect(formatKip(1250000.5), '₭1,250,000.50');
    expect(formatKip(999), '₭999.00');
  });

  test('whole kip and other prefixes', () {
    expect(formatKip(35000, decimals: 0), '₭35,000');
    expect(formatKip(35000, symbol: 'LAK '), 'LAK 35,000.00');
    expect(formatKip(5000, decimals: 0, symbol: ''), '5,000');
    expect(formatKip(null), '₭0.00');
  });

  test('stays 70,000 when the app runs in Lao', () {
    final old = Intl.defaultLocale;
    Intl.defaultLocale = 'lo';
    try {
      expect(formatKip(70000), '₭70,000.00');
    } finally {
      Intl.defaultLocale = old;
    }
  });
}
