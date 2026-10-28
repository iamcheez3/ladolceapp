import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/services/printer_service.dart';

void main() {
  final croissant = Product(id: 1, name: 'Butter croissant', price: 30000, category: 'Bakery');
  final cake = Product(id: 2, name: 'Cheesecake', price: 45000, category: 'Cake');
  final cream = Topping(id: 5, name: 'Whipped cream', extraPrice: 5000);
  final sizeL = Topping(id: 6, name: 'Size L', extraPrice: 5000);

  test('same item saved and added later prints as one 2x line', () {
    final lines = mergeSamePrintLines([
      CartItem(product: croissant, isSaved: true),
      CartItem(product: cake, selectedToppings: [cream]),
      CartItem(product: croissant),
    ]);
    expect(lines.length, 2);
    expect(lines[0].item.product.id, 1);
    expect(lines[0].quantity, 2);
    expect(lines[0].totalPrice, 60000);
    expect(lines[1].quantity, 1);
    expect(lines[1].totalPrice, 50000);
  });

  test('different choices or note stay on separate lines', () {
    expect(
      mergeSamePrintLines([
        CartItem(product: cake, selectedToppings: [cream]),
        CartItem(product: cake),
      ]).length,
      2,
    );
    expect(
      mergeSamePrintLines([
        CartItem(product: croissant, kitchenNote: 'warm'),
        CartItem(product: croissant),
      ]).length,
      2,
    );
  });

  test('choices in another order are still the same item', () {
    final lines = mergeSamePrintLines([
      CartItem(product: cake, selectedToppings: [cream, sizeL]),
      CartItem(product: cake, quantity: 2, selectedToppings: [sizeL, cream]),
    ]);
    expect(lines.length, 1);
    expect(lines[0].quantity, 3);
    expect(lines[0].totalPrice, 165000);
  });

  test('a free promo item never joins a paid one', () {
    final lines = mergeSamePrintLines([
      CartItem(product: croissant),
      CartItem(product: croissant, isFreePromo: true, promotionId: 7),
    ]);
    expect(lines.length, 2);
    expect(lines[1].totalPrice, 0);
  });

  test('a different price from the server stays separate', () {
    final lines = mergeSamePrintLines([
      CartItem(product: croissant, priceUnitFromOrder: 30000),
      CartItem(product: croissant, priceUnitFromOrder: 25000),
    ]);
    expect(lines.length, 2);
  });
}
