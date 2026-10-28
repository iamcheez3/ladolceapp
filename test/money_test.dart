import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/utils/money.dart';

void main() {
  test('whole kip with thousands separators', () {
    expect(money(90000), '90,000');
    expect(money(90000.0), '90,000');
    expect(money(1234567), '1,234,567');
    expect(money(500), '500');
    expect(money(0), '0');
    expect(money(null), '0');
  });

  test('rounds to whole kip, keeps the sign', () {
    expect(money(8750.4), '8,750');
    expect(money(8750.5), '8,751');
    expect(money(-5000), '-5,000');
  });

  test('parseMoney reads what the box shows', () {
    expect(parseMoney('90,000'), 90000);
    expect(parseMoney(' 1,234,567 '), 1234567);
    expect(parseMoney(''), 0);
  });

  group('MoneyInputFormatter', () {
    final f = MoneyInputFormatter();
    TextEditingValue type(String before, String after, int cursor) => f.formatEditUpdate(
          TextEditingValue(text: before),
          TextEditingValue(text: after, selection: TextSelection.collapsed(offset: cursor)),
        );

    test('adds commas while typing', () {
      final v = type('9,000', '9,0000', 6);
      expect(v.text, '90,000');
      expect(v.selection.end, 6);
    });

    test('drops letters, dots and other characters', () {
      expect(type('', '35000.5x', 8).text, '350,005');
      expect(type('', 'abc', 3).text, '');
    });

    test('deleting the last digit clears the box', () {
      expect(type('5', '', 0).text, '');
    });

    test('editing in the middle keeps the cursor after the same digit', () {
      // "12,345" → user inserts 9 after "12" → "129,345" (cursor after 9)
      final v = type('12,345', '129,345', 3);
      expect(v.text, '129,345');
      expect(v.selection.end, 3);
    });
  });
}
