import 'cart_item.dart';

/// A running "Buy X get Y free" promotion (backend pos_backend.promotion,
/// type buy_x_get_y). [productIds] are product.product ids, like Product.id.
class FreePromotion {
  final int id;
  final String name;
  final int buyQty;
  final int freeQty;
  /// Products that count as bought (e.g. 20 menus).
  final Set<int> productIds;

  /// Products that may be given free (e.g. 3 items). Older servers do not
  /// send it: then the bought products themselves.
  final Set<int> freeProductIds;

  const FreePromotion({
    required this.id,
    required this.name,
    required this.buyQty,
    required this.freeQty,
    required this.productIds,
    required this.freeProductIds,
  });

  factory FreePromotion.fromJson(Map<String, dynamic> json) {
    Set<int> ids(Object? raw) => {
          for (final id in (raw as List? ?? const []))
            if (id is int) id,
        };
    final buy = ids(json['product_ids']);
    final free = ids(json['free_product_ids']);
    return FreePromotion(
      id: json['id'],
      name: (json['name'] ?? '').toString(),
      buyQty: (json['buy_qty'] as num?)?.toInt() ?? 2,
      freeQty: (json['free_qty'] as num?)?.toInt() ?? 1,
      productIds: buy,
      freeProductIds: free.isEmpty ? buy : free,
    );
  }

  /// Paid (not free) quantity of this promotion's products in [cart].
  int paidQty(List<CartItem> cart) => cart
      .where((i) => !i.isFreePromo && !i.isRedeemed && productIds.contains(i.product.id))
      .fold(0, (s, i) => s + i.quantity);

  /// Free quantity already taken for this promotion.
  int usedFree(List<CartItem> cart) => cart
      .where((i) => i.isFreePromo && i.promotionId == id)
      .fold(0, (s, i) => s + i.quantity);

  /// How many free items the cart has earned (buy 2 get 1: 4 paid -> 2).
  int allowedFree(List<CartItem> cart) =>
      buyQty < 1 ? 0 : (paidQty(cart) ~/ buyQty) * freeQty;

  /// Free items still available to add (negative = too many taken, e.g. a
  /// paid item was removed after the free one was added).
  int availableFree(List<CartItem> cart) => allowedFree(cart) - usedFree(cart);
}
