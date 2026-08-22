import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/cart_item.dart';
import '../models/pos_discount_config.dart';
import '../models/pos_tax_config.dart';
import '../utils/pos_discount.dart';

class CartSidebar extends StatelessWidget {
  static const Color _brandNavy = Color(0xFF001460);
  static const Color _brandNavy2 = Color(0xFF142B8C);

  final List<CartItem> cartItems;
  final Function(CartItem, int) onUpdateQuantity;
  final VoidCallback onClearCart;
  final VoidCallback onCharge;
  final VoidCallback onSaveTicket;
  final VoidCallback onViewTickets;
  final ValueChanged<CartItem> onEditKitchenNote;

  final VoidCallback onAddCustomer;
  final VoidCallback onClearCustomer;
  final Map<String, dynamic>? selectedCustomer;
  final PosTaxConfig taxConfig;
  final PosDiscountOption? selectedDiscountOption;
  final double? discountManualValue;

  const CartSidebar({
    super.key,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onClearCart,
    required this.onCharge,
    required this.onSaveTicket,
    required this.onViewTickets,
    required this.onEditKitchenNote,
    required this.onAddCustomer,
    required this.onClearCustomer,
    this.selectedCustomer,
    this.taxConfig = PosTaxConfig.disabled,
    this.selectedDiscountOption,
    this.discountManualValue,
  });

  @override
  Widget build(BuildContext context) {
    final linesSum = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final cd = computeCartBreakdown(
      linesSum,
      taxConfig,
      selectedDiscountOption: selectedDiscountOption,
      discountManualValue: discountManualValue,
    );

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Loyverse Style Split Header Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: cartItems.isEmpty ? null : onSaveTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandNavy2,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF98A4D8),
                      disabledForegroundColor: Colors.white70,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(AppLocalizations.of(context)?.saveTicket ?? (AppLocalizations.of(context)?.saveTicket ?? 'SAVE TICKET'),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: cartItems.isEmpty ? null : onCharge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandNavy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF7E8BC8),
                      disabledForegroundColor: Colors.white70,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      elevation: 0,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(AppLocalizations.of(context)?.charge2 ?? (AppLocalizations.of(context)?.charge2 ?? 'CHARGE'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          Text(
                            '₭${cd.totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Add Customer Row
          InkWell(
            onTap: selectedCustomer == null ? onAddCustomer : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedCustomer != null ? Icons.person : Icons.person_add_alt_1_outlined, 
                    color: selectedCustomer != null ? Colors.blue.shade700 : Colors.grey.shade600, 
                    size: 22
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: selectedCustomer != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${selectedCustomer!['name']}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${selectedCustomer!['reward_points']} pts',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ],
                          )
                        : Text(AppLocalizations.of(context)?.addCustomer ?? (AppLocalizations.of(context)?.addCustomer ?? 'Add customer'),
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
                          ),
                  ),
                  if (selectedCustomer != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: onClearCustomer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          
          // Current Ticket sub-header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)?.currentTicket2 ?? (AppLocalizations.of(context)?.currentTicket2 ?? 'Current Ticket'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _brandNavy,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: cartItems.isEmpty ? null : onClearCart,
                  tooltip: AppLocalizations.of(context)?.clearTicket2 ?? (AppLocalizations.of(context)?.clearTicket2 ?? 'Clear Ticket'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Cart Items — split into Saved and New sections
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(AppLocalizations.of(context)?.noItemsInTicket ?? (AppLocalizations.of(context)?.noItemsInTicket ?? 'No items in ticket'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  )
                : Builder(builder: (context) {
                    final savedItems = cartItems.where((i) => i.isSaved).toList();
                    final newItems = cartItems.where((i) => !i.isSaved).toList();

                    return ListView(
                      children: [
                        // ── Already Ordered ──────────────────────────────────
                        if (savedItems.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: const Color(0xFFF0F4FF),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: Color(0xFF1E3A8A)),
                                const SizedBox(width: 6),
                                Text(AppLocalizations.of(context)?.alreadyOrdered ?? (AppLocalizations.of(context)?.alreadyOrdered ?? 'ALREADY ORDERED'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...savedItems.map((item) => _CartItemRow(
                                item: item,
                                isSaved: true,
                                onUpdateQuantity: onUpdateQuantity,
                                onEditKitchenNote: onEditKitchenNote,
                              )),
                          const Divider(height: 1, thickness: 2, color: Color(0xFFE3E8F0)),
                        ],

                        // ── New Items ─────────────────────────────────────────
                        if (newItems.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: const Color(0xFFFFF8E1),
                            child: Row(
                              children: [
                                const Icon(Icons.fiber_new, size: 16, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(AppLocalizations.of(context)?.newItems ?? (AppLocalizations.of(context)?.newItems ?? 'NEW ITEMS'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800],
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...newItems.map((item) => _CartItemRow(
                                item: item,
                                isSaved: false,
                                onUpdateQuantity: onUpdateQuantity,
                                onEditKitchenNote: onEditKitchenNote,
                              )),
                        ],

                        // If only one type, no divider needed
                        if (savedItems.isEmpty && newItems.isEmpty)
                          Center(
                            child: Text(AppLocalizations.of(context)?.noItems ?? (AppLocalizations.of(context)?.noItems ?? 'No items'), style: TextStyle(color: Colors.grey[500])),
                          ),
                      ],
                    );
                  }),
          ),
          
          // Totals and Charge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Subtotal ──────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(AppLocalizations.of(context)?.subtotal ?? (AppLocalizations.of(context)?.subtotal ?? 'Subtotal'),
                        style: TextStyle(color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '₭${cd.cartLinesSum.toStringAsFixed(2)}',
                        textAlign: TextAlign.end,
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),



                // ── Tax Breakdown ─────────────────────────────────────────────
                if (!cd.taxActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(AppLocalizations.of(context)?.total ?? (AppLocalizations.of(context)?.total ?? 'Total'),
                          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₭${cd.totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _brandNavy),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taxConfig.inclusive ? (AppLocalizations.of(context)?.amountExclVat2 ?? 'Amount (excl. VAT)') : (AppLocalizations.of(context)?.subtotalExclVat ?? 'Subtotal (excl. VAT)'),
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '₭${cd.baseAmount.toStringAsFixed(2)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                  if (taxConfig.showOnReceipt) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'VAT (${taxConfig.percentLabel}%)',
                            style: TextStyle(color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '₭${cd.taxAmount.toStringAsFixed(2)}',
                            textAlign: TextAlign.end,
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLocalizations.of(context)?.totalDue ?? (AppLocalizations.of(context)?.totalDue ?? 'Total due'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              taxConfig.showOnReceipt
                                  ? (taxConfig.inclusive ? (AppLocalizations.of(context)?.priceIncludesTax ?? 'Price includes tax') : (AppLocalizations.of(context)?.includesVat ?? 'Includes VAT'))
                                  : (AppLocalizations.of(context)?.taxHiddenOnReceipt ?? 'Tax hidden on receipt'),
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₭${cd.totalDue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _brandNavy),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],



                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable cart row widget ────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final bool isSaved;
  final Function(CartItem, int) onUpdateQuantity;
  final ValueChanged<CartItem> onEditKitchenNote;

  const _CartItemRow({
    required this.item,
    required this.isSaved,
    required this.onUpdateQuantity,
    required this.onEditKitchenNote,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isSaved ? Colors.grey[700]! : Colors.black87;
    final priceColor = isSaved ? Colors.grey[600]! : const Color(0xFF001460);
    final iconColor = isSaved ? Colors.grey[500]! : const Color(0xFF001460);

    return Material(
      color: isSaved ? const Color(0xFFFAFBFF) : Colors.white,
      child: InkWell(
        onTap: () => onEditKitchenNote(item),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Qty controls — locked for saved items, interactive for new
            if (isSaved) ...[
              // Static read-only badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${item.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Interactive +/- for new items
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: iconColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => onUpdateQuantity(item, item.quantity - 1),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: iconColor),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => onUpdateQuantity(item, item.quantity + 1),
              ),
            ],
            const SizedBox(width: 8),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: textColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₭${item.product.effectivePrice.toStringAsFixed(2)} each',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  if (item.selectedToppings.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.selectedToppings.map((topping) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Text(
                            '+ ${topping.name} (₭${topping.extraPrice.toStringAsFixed(2)})',
                            style: TextStyle(fontSize: 10, color: Colors.orange[800]),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (item.kitchenNote.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 14,
                          color: Colors.amber[800],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.kitchenNote.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber[900],
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '₭${item.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: priceColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
