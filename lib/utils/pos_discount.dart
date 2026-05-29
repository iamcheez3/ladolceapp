import '../models/pos_discount_config.dart';
import '../models/pos_tax_config.dart';
import 'pos_tax.dart';

/// Result of discount computation.
class DiscountBreakdown {
  /// Whether a discount is active.
  final bool active;

  /// Discount amount in currency.
  final double discountAmount;

  /// For percentage type, the rate used (e.g. 10.0 for 10%).
  final double? percentUsed;

  /// Human-readable label (e.g. "10% Off" or "₭5,000 Off").
  final String label;

  const DiscountBreakdown({
    required this.active,
    required this.discountAmount,
    this.percentUsed,
    required this.label,
  });

  static const DiscountBreakdown none = DiscountBreakdown(
    active: false,
    discountAmount: 0,
    label: '',
  );
}

/// Combined breakdown including discount + tax.
class CartBreakdown {
  final double cartLinesSum;
  final DiscountBreakdown discount;
  final PosTaxBreakdown tax;

  /// Amount after discount (before tax).
  final double discountedSubtotal;

  const CartBreakdown({
    required this.cartLinesSum,
    required this.discount,
    required this.tax,
    required this.discountedSubtotal,
  });

  double get totalDue => tax.totalDue;
  double get baseAmount => tax.baseAmount;
  double get taxAmount => tax.taxAmount;
  bool get taxActive => tax.taxActive;
  bool get discountActive => discount.active;
}

/// Compute discount from config and cart subtotal.
DiscountBreakdown computePosDiscount(
  double cartSubtotal,
  PosDiscountOption? option, {
  double? manualValue,
}) {
  if (option == null || cartSubtotal <= 0) {
    return DiscountBreakdown.none;
  }

  if (option.type == 'percentage') {
    final pct = (option.value ?? manualValue ?? 0.0).clamp(0.0, 100.0);
    final amount = cartSubtotal * pct / 100.0;
    final label = pct == pct.roundToDouble()
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
    return DiscountBreakdown(
      active: amount > 0,
      discountAmount: amount,
      percentUsed: pct,
      label: '${option.name} ($label)',
    );
  }

  // Fixed value discount
  final val = (option.value ?? manualValue ?? 0.0).clamp(0.0, cartSubtotal);
  return DiscountBreakdown(
    active: val > 0,
    discountAmount: val,
    label: option.isManual
        ? '${option.name} (₭${val.toStringAsFixed(0)})'
        : '${option.name} (₭${val.toStringAsFixed(0)})',
  );
}

/// Compute full cart breakdown: discount first, then tax on discounted amount.
CartBreakdown computeCartBreakdown(
  double cartLinesSum,
  PosTaxConfig taxConfig, {
  PosDiscountOption? selectedDiscountOption,
  double? discountManualValue,
  DiscountBreakdown? overrideDiscount,
}) {
  final discount = overrideDiscount ??
      computePosDiscount(cartLinesSum, selectedDiscountOption,
          manualValue: discountManualValue);

  final discountedSubtotal =
      (cartLinesSum - discount.discountAmount).clamp(0.0, cartLinesSum);

  final tax = computePosTaxBreakdown(discountedSubtotal, taxConfig);

  return CartBreakdown(
    cartLinesSum: cartLinesSum,
    discount: discount,
    tax: tax,
    discountedSubtotal: discountedSubtotal,
  );
}
