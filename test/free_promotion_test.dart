import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/free_promotion.dart';
import 'package:ladolce/models/product.dart';

void main() {
  final promo = FreePromotion.fromJson({
    'id': 7,
    'name': 'Buy 2 Get 1 Coffee',
    'buy_qty': 2,
    'free_qty': 1,
    'product_ids': [1, 2],
  });
  Product p(int id) => Product(id: id, name: 'P$id', price: 30000, category: 'Coffee');
  CartItem paid(int id, int qty) => CartItem(product: p(id), quantity: qty);
  CartItem free(int id, int qty) =>
      CartItem(product: p(id), quantity: qty, isFreePromo: true, promotionId: 7, promotionName: 'B2G1');

  test('2 paid promo items earn 1 free, 4 earn 2', () {
    expect(promo.availableFree([paid(1, 2)]), 1);
    expect(promo.availableFree([paid(1, 1), paid(2, 3)]), 2);
    expect(promo.availableFree([paid(1, 1)]), 0);
  });

  test('free list separate from buy list; empty = same as buy list', () {
    final split = FreePromotion.fromJson({
      'id': 8, 'name': 'X', 'buy_qty': 2, 'free_qty': 1,
      'product_ids': [1, 2, 3], 'free_product_ids': [9],
    });
    expect(split.freeProductIds, {9});
    expect(split.availableFree([paid(1, 1), paid(3, 1)]), 1);
    expect(promo.freeProductIds, {1, 2});
  });

  test('items outside the promotion do not count', () {
    expect(promo.availableFree([paid(1, 1), paid(9, 5)]), 0);
  });

  test('taken free items reduce what is left; removing a paid one goes negative', () {
    expect(promo.availableFree([paid(1, 2), free(2, 1)]), 0);
    expect(promo.availableFree([paid(1, 1), free(2, 1)]), -1);
  });

  test('a free line costs nothing, choices included', () {
    expect(free(1, 2).totalPrice, 0);
    expect(paid(1, 2).totalPrice, 60000);
  });
}
