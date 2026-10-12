import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/cart_item.dart';
import 'package:ladolce/models/free_promotion.dart';
import 'package:ladolce/models/product.dart';

Product _p(int id, double price) =>
    Product(id: id, name: 'P$id', price: price, category: 'Coffee');

void main() {
  final aerocano = _p(1, 35000);
  final honey = _p(2, 40000);
  final brownie = _p(3, 35000);
  final water = _p(9, 5000);

  // "2 free 1": two coffees give one Brownie or Cloud No.3.
  final promo = FreePromotion.fromJson({
    'id': 4,
    'name': '2 free 1',
    'buy_qty': 2,
    'free_qty': 1,
    'product_ids': [1, 2],
    'free_product_ids': [3, 7],
  });

  test('two promo items earn one free item', () {
    final cart = [CartItem(product: aerocano), CartItem(product: honey)];
    expect(promo.allowedQty(cart), 1);
    expect(promo.availableQty(cart), 1);
    expect(promotionsWithFreeItems([promo], cart), [promo]);
  });

  test('items outside the promotion do not count', () {
    final cart = [CartItem(product: aerocano), CartItem(product: water)];
    expect(promo.availableQty(cart), 0);
    expect(promotionsWithFreeItems([promo], cart), isEmpty);
  });

  test('a chosen free item is ₭0 and uses the allowance', () {
    final free = CartItem(
      product: brownie,
      isFreePromo: true,
      promotionId: 4,
    );
    final cart = [CartItem(product: aerocano, quantity: 2), free];
    expect(free.totalPrice, 0);
    expect(promo.usedQty(cart), 1);
    expect(promo.availableQty(cart), 0);
    // A free item does not count as bought.
    expect(promo.paidQty([...cart, CartItem(product: honey, isFreePromo: true, promotionId: 4)]), 2);
  });

  test('removing a paid item leaves the free one over the limit', () {
    final cart = [
      CartItem(product: aerocano),
      CartItem(product: brownie, isFreePromo: true, promotionId: 4),
    ];
    expect(promo.isOverused(cart), isTrue);
    expect(overusedPromotion([promo], cart), promo);
  });

  test('four items earn two, five still two', () {
    expect(promo.allowedQty([CartItem(product: aerocano, quantity: 4)]), 2);
    expect(promo.allowedQty([CartItem(product: aerocano, quantity: 5)]), 2);
  });

  test('no free products listed means the bought products', () {
    final same = FreePromotion.fromJson({
      'id': 5,
      'name': 'buy 3 get 1',
      'buy_qty': 3,
      'free_qty': 1,
      'product_ids': [1],
      'free_product_ids': [],
    });
    expect(same.canGiveFree(1), isTrue);
    expect(same.canGiveFree(3), isFalse);
    expect(promo.canGiveFree(3), isTrue);
  });
}
