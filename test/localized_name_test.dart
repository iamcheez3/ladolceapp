import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/utils/localized_name.dart';

void main() {
  tearDown(() => DisplayLanguage.code = 'en');

  group('localizedName', () {
    test('uses the English label when the app is in English', () {
      DisplayLanguage.code = 'en';
      expect(localizedName('Iced Latte', 'ລາເຕ້ເຢັນ'), 'Iced Latte');
    });

    test('uses the Lao label when the app is in Lao', () {
      DisplayLanguage.code = 'lo';
      expect(localizedName('Iced Latte', 'ລາເຕ້ເຢັນ'), 'ລາເຕ້ເຢັນ');
    });

    test('falls back to English when no Lao label was saved', () {
      DisplayLanguage.code = 'lo';
      expect(localizedName('Blueberry Muffin', ''), 'Blueberry Muffin');
      expect(localizedName('Blueberry Muffin', null), 'Blueberry Muffin');
      expect(localizedName('Blueberry Muffin', '   '), 'Blueberry Muffin');
    });

    test('falls back to the placeholder when both labels are missing', () {
      DisplayLanguage.code = 'lo';
      expect(localizedName(null, null), 'Item');
      expect(localizedName('', '', fallback: 'Voucher'), 'Voucher');
    });
  });

  group('localizedLineName', () {
    final line = {
      'product_name': 'Iced Latte',
      'product_name_lo': 'ລາເຕ້ເຢັນ',
      'qty': 2,
    };

    test('reads both label fields off an order line', () {
      DisplayLanguage.code = 'lo';
      expect(localizedLineName(line), 'ລາເຕ້ເຢັນ');
      DisplayLanguage.code = 'en';
      expect(localizedLineName(line), 'Iced Latte');
    });

    test('handles a line from before the backend sent Lao labels', () {
      DisplayLanguage.code = 'lo';
      expect(localizedLineName({'product_name': 'Espresso'}), 'Espresso');
      expect(localizedLineName(const {}), 'Item');
    });
  });

  group('Product.displayName', () {
    test('follows the display language', () {
      final product = Product.fromJson({
        'id': 118,
        'name': 'Iced Latte',
        'name_lo': 'ລາເຕ້ເຢັນ',
        'list_price': 30000.0,
        'category': 'Coffee',
      });

      DisplayLanguage.code = 'en';
      expect(product.displayName, 'Iced Latte');
      DisplayLanguage.code = 'lo';
      expect(product.displayName, 'ລາເຕ້ເຢັນ');
    });

    test('survives a payload with no name_lo at all', () {
      final product = Product.fromJson({
        'id': 119,
        'name': 'Blueberry Muffin',
        'list_price': 25000.0,
        'category': 'Bakery',
      });

      DisplayLanguage.code = 'lo';
      expect(product.nameLo, '');
      expect(product.displayName, 'Blueberry Muffin');
    });
  });
}
