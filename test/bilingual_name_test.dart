import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/utils/bilingual_name.dart';

/// The backend ships `name`/`name_lo` (and `product_name`/`product_name_lo`)
/// together on every payload, already falling back to English server-side, so
/// switching language is a rebuild rather than a refetch.
void main() {
  Product make({required String name, String? nameLo}) =>
      Product(id: 1, name: name, nameLo: nameLo, price: 0, category: 'Coffee');

  tearDown(() => Product.useLaoNames = false);

  group('Product.displayName', () {
    test('uses English while the app is in English', () {
      Product.useLaoNames = false;
      expect(make(name: 'Iced Latte', nameLo: 'ລາເຕ້ເຢັນ').displayName,
          'Iced Latte');
    });

    test('uses Lao once the app switches to Lao', () {
      Product.useLaoNames = true;
      expect(make(name: 'Iced Latte', nameLo: 'ລາເຕ້ເຢັນ').displayName,
          'ລາເຕ້ເຢັນ');
    });

    test('falls back to English for an untranslated product', () {
      Product.useLaoNames = true;
      // A half-translated catalogue must stay shippable.
      expect(make(name: 'Blueberry Muffin', nameLo: null).displayName,
          'Blueberry Muffin');
      expect(make(name: 'Blueberry Muffin', nameLo: '   ').displayName,
          'Blueberry Muffin');
    });
  });

  group('Product.matchesQuery', () {
    final p = make(name: 'Iced Latte', nameLo: 'ລາເຕ້ເຢັນ');

    test('matches either language regardless of the current locale', () {
      for (final lao in [false, true]) {
        Product.useLaoNames = lao;
        expect(p.matchesQuery('latte'), isTrue, reason: 'English, lao=$lao');
        expect(p.matchesQuery('ລາເຕ້'), isTrue, reason: 'Lao, lao=$lao');
        expect(p.matchesQuery('espresso'), isFalse);
      }
    });

    test('an empty query matches everything', () {
      expect(p.matchesQuery('  '), isTrue);
    });
  });

  group('bilingualName', () {
    const line = {
      'product_name': 'Iced Latte',
      'product_name_lo': 'ລາເຕ້ເຢັນ',
    };

    test('follows the locale flag', () {
      Product.useLaoNames = false;
      expect(bilingualName(line), 'Iced Latte');
      Product.useLaoNames = true;
      expect(bilingualName(line), 'ລາເຕ້ເຢັນ');
    });

    test('survives an older backend that omits the Lao key', () {
      Product.useLaoNames = true;
      expect(bilingualName(const {'product_name': 'Iced Latte'}), 'Iced Latte');
    });

    test('falls back when the payload names nothing', () {
      expect(bilingualName(const {}, fallback: 'Item'), 'Item');
    });

    test('reads other bilingual fields too', () {
      Product.useLaoNames = true;
      expect(
        bilingualName(const {'name': 'Latte', 'name_lo': 'ລາເຕ້'}, field: 'name'),
        'ລາເຕ້',
      );
    });
  });
}
