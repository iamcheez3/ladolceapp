import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/ld.dart';
import 'product_grid.dart';

/// Product catalog as rows: picture (or initial), name with the English name
/// under it, price in the receipt font, gold badge with the quantity already
/// in the ticket.
class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  /// Quantity of each product (by id) already in the current ticket.
  final Map<int, int> cartQuantities;

  const ProductList({
    super.key,
    required this.products,
    required this.onProductTap,
    this.cartQuantities = const {},
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Ld.ground,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final product = products[index];
          final qty = cartQuantities[product.id] ?? 0;
          final initial = product.displayName.trim().isNotEmpty
              ? product.displayName.trim().characters.first.toUpperCase()
              : '?';
          final image = productImage(product);
          final secondary = productSecondaryName(product);

          return Material(
            color: Ld.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Ld.rMd),
              side: BorderSide(color: qty > 0 ? Ld.navy : Ld.line, width: qty > 0 ? 1.5 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onProductTap(product),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 68),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(Ld.r),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: Ld.ground,
                          alignment: Alignment.center,
                          child: image ??
                              Text(
                                initial,
                                style: Ld.title(18),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Ld.ink,
                                height: 1.3,
                              ),
                            ),
                            if (secondary != null)
                              Text(
                                secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Ld.muted, fontSize: 12.5, height: 1.3),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width < 400 ? 104 : 150,
                        ),
                        child: ProductPriceLabel(product, size: 16, align: CrossAxisAlignment.end),
                      ),
                      if (qty > 0) ...[
                        const SizedBox(width: 10),
                        ProductQtyBadge(qty),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
