import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/ladolce_pos_ui.dart';
import '../utils/responsive_layout.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxExtent = ResponsiveLayout.productGridMaxCrossAxisExtent(context);
    final aspect = ResponsiveLayout.productGridChildAspectRatio(context);
    return Container(
      color: LaDolcePosUi.surface,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxExtent,
          childAspectRatio: aspect,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final initial = product.name.trim().isNotEmpty ? product.name.trim()[0].toUpperCase() : '?';
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final isCompactText = textScale > 1.1;
          final imageBytes = product.decodedImageBytes;

          return InkWell(
            onTap: () => onProductTap(product),
            borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
            child: Container(
              decoration: BoxDecoration(
                color: LaDolcePosUi.card,
                borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                border: Border.all(color: LaDolcePosUi.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardHeight = constraints.maxHeight;
                  final imageHeight = (cardHeight * (isCompactText ? 0.50 : 0.54)).clamp(84.0, 132.0);
                  final horizontalPadding = cardHeight < 220 ? 10.0 : 12.0;
                  final verticalPadding = cardHeight < 220 ? 8.0 : 10.0;
                  final nameSize = cardHeight < 220 ? 13.0 : 14.0;
                  final categorySize = cardHeight < 220 ? 10.5 : 11.5;
                  final priceSize = cardHeight < 220 ? 11.0 : 12.0;
                  final gap = cardHeight < 220 ? 6.0 : 8.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: imageHeight,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(LaDolcePosUi.radius)),
                          child: Container(
                            color: LaDolcePosUi.navy.withOpacity(0.06),
                            child: imageBytes != null
                                ? Image.memory(
                                    imageBytes,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                : (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                        product.imageUrl!,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      )
                                    : Center(
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: LaDolcePosUi.navy.withOpacity(0.10),
                                            border: Border.all(color: LaDolcePosUi.navy.withOpacity(0.18)),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              color: LaDolcePosUi.navy,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            verticalPadding,
                            horizontalPadding,
                            verticalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: nameSize,
                                  color: LaDolcePosUi.text,
                                ),
                                maxLines: isCompactText ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: gap),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.category,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: LaDolcePosUi.mutedText,
                                          fontSize: categorySize,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (product.promotionPrice != null && !Product.disablePromotionPrice)
                                          Text(
                                            '₭${product.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: priceSize - 2,
                                              color: Colors.grey.shade400,
                                              decoration: TextDecoration.lineThrough,
                                            ),
                                          ),
                                        Text(
                                          '₭${product.effectivePrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: (product.promotionPrice != null && !Product.disablePromotionPrice)
                                                ? Colors.red
                                                : LaDolcePosUi.navy,
                                            fontWeight: FontWeight.w800,
                                            fontSize: priceSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
