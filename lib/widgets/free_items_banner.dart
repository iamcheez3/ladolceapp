import 'package:flutter/material.dart';

import '../models/free_promotion.dart';
import '../models/product.dart';
import '../utils/l10n_ext.dart';
import '../utils/money.dart';

/// 🎁 "2 free 1: 1 free item(s)" with a button ("Add free" on the POS,
/// "Choose" in the customer cart). Shown while the cart has earned free items.
class FreeItemsBanner extends StatelessWidget {
  final FreePromotion promotion;
  final int count;
  final String buttonLabel;
  final VoidCallback onPressed;

  const FreeItemsBanner({
    super.key,
    required this.promotion,
    required this.count,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF81C784)),
      ),
      child: Row(
        children: [
          const Text('🎁', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.l10n.freeItemsAvailable(promotion.name, '$count'),
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: Text(buttonLabel, style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// "Choose the free item (2 free 1)": the promotion's free products, struck
/// through price, FREE. Returns the chosen product, or null.
Future<Product?> showFreeItemPicker(
  BuildContext context, {
  required FreePromotion promotion,
  required List<Product> products,
  Color titleColor = Colors.black87,
}) {
  final choices = [
    for (final id in promotion.freeProductIds)
      ...products.where((p) => p.id == id),
  ];
  return showModalBottomSheet<Product>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ctx.l10n.chooseFreeItem(promotion.name),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in choices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Text('🎁', style: TextStyle(fontSize: 26)),
                      title: Text(
                        p.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: Text(
                        formatKip(p.effectivePrice, decimals: 0),
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          fontSize: 15,
                        ),
                      ),
                      trailing: Text(
                        ctx.l10n.freeUpper,
                        style: const TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
