import 'cart_item.dart';

/// A running "Buy X get Y free" promotion, from
/// `GET /api/pos/promotions/free_items`.
///
/// Buying [buyQty] of [productIds] earns [freeQty] items of
/// [freeProductIds] at ₭0 (choices included). Nothing is added on its own:
/// the cashier or the customer picks the free item, and the server checks the
/// counts again (`_check_free_promos`).
class FreePromotion {
  final int id;
  final String name;
  final int buyQty;
  final int freeQty;

  /// Products that count as bought (`product.product` ids, as in /api/products).
  final Set<int> productIds;

  /// Products that may be given free.
  final List<int> freeProductIds;

  FreePromotion({
    required this.id,
    required this.name,
    required this.buyQty,
    required this.freeQty,
    required this.productIds,
    required this.freeProductIds,
  });

  static List<int> _ids(dynamic raw) => raw is List
      ? raw
            .map((e) => e is num ? e.toInt() : int.tryParse('$e') ?? 0)
            .where((e) => e > 0)
            .toList()
      : <int>[];

  factory FreePromotion.fromJson(Map<String, dynamic> json) {
    final buy = (json['buy_qty'] as num?)?.toInt() ?? 0;
    final free = (json['free_qty'] as num?)?.toInt() ?? 0;
    final products = _ids(json['product_ids']);
    final freeProducts = _ids(json['free_product_ids']);
    return FreePromotion(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      buyQty: buy < 1 ? 1 : buy,
      freeQty: free < 0 ? 0 : free,
      productIds: products.toSet(),
      // Empty = the bought products themselves (backend `_free_products`).
      freeProductIds: freeProducts.isEmpty ? products : freeProducts,
    );
  }

  /// Paid items in [cart] that count towards this promotion.
  int paidQty(List<CartItem> cart) => cart
      .where(
        (i) =>
            !i.isFreePromo &&
            !i.isRedeemed &&
            productIds.contains(i.product.id),
      )
      .fold(0, (sum, i) => sum + i.quantity);

  /// Free items this promotion already gave in [cart].
  int usedQty(List<CartItem> cart) => cart
      .where((i) => i.isFreePromo && i.promotionId == id)
      .fold(0, (sum, i) => sum + i.quantity);

  /// Free items the cart has earned: (paid ÷ X) × Y.
  int allowedQty(List<CartItem> cart) => (paidQty(cart) ~/ buyQty) * freeQty;

  /// Free items still to choose.
  int availableQty(List<CartItem> cart) {
    final left = allowedQty(cart) - usedQty(cart);
    return left > 0 ? left : 0;
  }

  /// More free items than the paid ones allow (e.g. a paid item was removed).
  bool isOverused(List<CartItem> cart) => usedQty(cart) > allowedQty(cart);

  bool canGiveFree(int productId) => freeProductIds.contains(productId);
}

/// Promotions with free items left to choose in [cart].
List<FreePromotion> promotionsWithFreeItems(
  List<FreePromotion> promotions,
  List<CartItem> cart,
) => promotions.where((p) => p.availableQty(cart) > 0).toList();

/// First promotion whose free items exceed what [cart] allows, if any.
FreePromotion? overusedPromotion(
  List<FreePromotion> promotions,
  List<CartItem> cart,
) {
  for (final p in promotions) {
    if (p.isOverused(cart)) return p;
  }
  // A free line whose promotion stopped running cannot be checked here; the
  // server decides (a ticket saved during the promotion stays valid).
  return null;
}
