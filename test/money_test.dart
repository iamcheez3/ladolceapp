import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:ladolce/utils/money.dart';

void main() {
  group('ThousandsInputFormatter', formatterTests);

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

TextEditingValue _type(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

TextEditingValue _edit(TextEditingValue old, TextEditingValue now) =>
    const ThousandsInputFormatter().formatEditUpdate(old, now);

void formatterTests() {
  test('typing puts commas in', () {
    final v = _edit(_type('10000'), _type('100000'));
    expect(v.text, '100,000');
    expect(v.selection.extentOffset, 7);
    expect(_edit(_type(''), _type('7')).text, '7');
    expect(_edit(_type('1,234'), _type('1,2345')).text, '12,345');
  });

  test('a digit typed in the middle keeps the caret after it', () {
    // "1,000" with the caret after the 1, type 5 -> "15,000", caret after 5.
    final v = _edit(_type('1,000', 1), _type('15,000', 2));
    expect(v.text, '15,000');
    expect(v.selection.extentOffset, 2);
  });

  test('backspace over a comma deletes the digit before it', () {
    // "12,000" caret after the comma; backspace removes the comma.
    final v = _edit(_type('12,000', 3), _type('12000', 2));
    expect(v.text, '1,000');
    expect(v.selection.extentOffset, 1);
  });

  test('decimals, leading zeros and junk', () {
    expect(_edit(_type(''), _type('1234.5')).text, '1,234.5');
    expect(_edit(_type(''), _type('1234.567')).text, '1,234.56');
    expect(_edit(_type(''), _type('007')).text, '7');
    expect(_edit(_type(''), _type('.5')).text, '0.5');
    expect(_edit(_type(''), _type('1a2b3')).text, '123');
    expect(_edit(_type('5'), _type('')).text, '');
  });

  test('a pasted formatted amount stays the same', () {
    expect(_edit(_type(''), _type('136,000')).text, '136,000');
  });
}
