import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/product.dart';
import '../theme/ladolce_pos_ui.dart';

class ProductList extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;

  const ProductList({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LaDolcePosUi.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final initial = product.name.trim().isNotEmpty ? product.name.trim()[0].toUpperCase() : '?';
          Uint8List? imageBytes;
          if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
            try {
              imageBytes = base64Decode(product.imageBase64!);
            } catch (_) {
              imageBytes = null;
            }
          }

          return InkWell(
            onTap: () => onProductTap(product),
            borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LaDolcePosUi.card,
                borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                border: Border.all(color: LaDolcePosUi.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
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
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: LaDolcePosUi.navy,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: LaDolcePosUi.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LaDolcePosUi.mutedText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: LaDolcePosUi.navy.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: LaDolcePosUi.navy.withOpacity(0.14)),
                        ),
                        child: Text(
                          '₭${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: LaDolcePosUi.navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
