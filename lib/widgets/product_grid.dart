import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/product.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

/// Product catalog as flat paper tiles: name (Lao when the app is in Lao),
/// the English name small under it, the price in the receipt font, a gold
/// badge with the quantity already in the ticket, and "Enter price" for an
/// item without a fixed price.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  /// Quantity of each product (by id) already in the current ticket.
  final Map<int, int> cartQuantities;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.cartQuantities = const {},
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    final anyImage = products.any(productHasImage);
    return ColoredBox(
      color: Ld.ground,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final pad = w < 360 ? 10.0 : (w < 600 ? 12.0 : 16.0);
          final gap = w < 600 ? 10.0 : 14.0;
          final maxExtent = w < 360 ? 160.0 : (w < 600 ? 190.0 : 220.0);
          final tileHeight = (anyImage ? 200.0 : 140.0) * (1 + (textScale - 1) * 0.85);
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 8),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              mainAxisExtent: tileHeight,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return _ProductTile(
                product: product,
                quantity: cartQuantities[product.id] ?? 0,
                onTap: () => onProductTap(product),
              );
            },
          );
        },
      ),
    );
  }
}

/// True when the product carries a picture (inline bytes or a URL).
bool productHasImage(Product p) =>
    p.decodedImageBytes != null || (p.imageUrl != null && p.imageUrl!.isNotEmpty);

/// A product saved with price 0 has no fixed price: the cashier types it
/// when adding it (same rule as the POS screen).
bool productIsOpenPrice(Product p) =>
    !p.isCombo && p.price <= 0 && p.effectivePrice <= 0;

/// The English name under the display name, when the display name is Lao.
String? productSecondaryName(Product p) {
  final shown = p.displayName.trim();
  final en = p.name.trim();
  if (en.isEmpty || en == shown) return null;
  return en;
}

/// Picture of a product, or null when it has none.
Widget? productImage(Product p) {
  final bytes = p.decodedImageBytes;
  if (bytes != null) {
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
  if (p.imageUrl != null && p.imageUrl!.isNotEmpty) {
    return Image.network(
      p.imageUrl!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return null;
}

/// Gold quantity badge for an item already in the ticket.
class ProductQtyBadge extends StatelessWidget {
  final int quantity;
  const ProductQtyBadge(this.quantity, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Ld.gold, borderRadius: BorderRadius.circular(15)),
      child: Text(
        quantity > 999 ? '999+' : '$quantity',
        style: const TextStyle(color: Ld.navy, fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
      ),
    );
  }
}

/// Price of a product in the receipt font: promotion price with the old one
/// struck through, or "Enter price" for an item without a fixed price.
class ProductPriceLabel extends StatelessWidget {
  final Product product;
  final double size;
  final CrossAxisAlignment align;

  const ProductPriceLabel(this.product, {super.key, this.size = 18, this.align = CrossAxisAlignment.start});

  @override
  Widget build(BuildContext context) {
    if (productIsOpenPrice(product)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_outlined, size: 16, color: Ld.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppLocalizations.of(context)?.enterPrice ?? 'Enter price',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Ld.muted),
            ),
          ),
        ],
      );
    }
    final promo = product.promotionPrice != null && !Product.disablePromotionPrice;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align == CrossAxisAlignment.end ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: align,
        children: [
          if (promo)
            Text(
              '₭${money(product.price)}',
              style: TextStyle(
                fontFamily: Ld.serif,
                fontSize: size - 5,
                color: Ld.muted,
                decoration: TextDecoration.lineThrough,
                height: 1.2,
              ),
            ),
          Text(
            '₭${money(product.effectivePrice)}',
            style: Ld.price(size, color: promo ? Ld.danger : Ld.navy, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.quantity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = productImage(product);
    final secondary = productSecondaryName(product);
    final inCart = quantity > 0;
    return Material(
      color: Ld.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: BorderSide(color: inCart ? Ld.navy : Ld.line, width: inCart ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) {
            final compact = box.maxWidth < 150;
            final pad = compact ? 12.0 : 14.0;
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (image != null)
                      SizedBox(
                        height: (box.maxHeight * 0.4).clamp(56.0, 96.0),
                        child: ColoredBox(color: Ld.ground, child: image),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          pad,
                          image != null ? 10 : pad,
                          // Room for the badge on text-only tiles.
                          image == null && inCart ? pad + 30 : pad,
                          compact ? 10 : 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w600,
                                color: Ld.ink,
                                height: 1.3,
                              ),
                            ),
                            if (secondary != null)
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: Ld.muted, height: 1.3),
                              ),
                            const Spacer(),
                            ProductPriceLabel(product, size: compact ? 16 : 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (inCart)
                  Positioned(top: 10, right: 10, child: ProductQtyBadge(quantity)),
              ],
            );
          },
        ),
      ),
    );
  }
}
