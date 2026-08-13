import '../models/pos_tax_config.dart';

/// Cart totals aligned with Odoo `pos_backend.order` amount computation.
class PosTaxBreakdown {
  /// Sum of cart line totals (same as historical "subtotal" fold).
  final double cartLinesSum;
  final bool taxActive;
  /// Amount shown as first row before VAT line on receipt (excl. VAT when inclusive mode).
  final double baseAmount;
  final double taxAmount;
  /// Amount the customer pays (matches Odoo `amount_total`).
  final double totalDue;

  const PosTaxBreakdown({
    required this.cartLinesSum,
    required this.taxActive,
    required this.baseAmount,
    required this.taxAmount,
    required this.totalDue,
  });
}

PosTaxBreakdown computePosTaxBreakdown(
  double cartLinesSum,
  PosTaxConfig config,
) {
  if (!config.active || config.percent <= 0) {
    return PosTaxBreakdown(
      cartLinesSum: cartLinesSum,
      taxActive: false,
      baseAmount: cartLinesSum,
      taxAmount: 0,
      totalDue: cartLinesSum,
    );
  }

  final r = config.percent;
  if (config.inclusive) {
    final tax = cartLinesSum * r / (100.0 + r);
    final net = cartLinesSum - tax;
    return PosTaxBreakdown(
      cartLinesSum: cartLinesSum,
      taxActive: true,
      baseAmount: net,
      taxAmount: tax,
      totalDue: cartLinesSum,
    );
  }

  final tax = cartLinesSum * r / 100.0;
  return PosTaxBreakdown(
    cartLinesSum: cartLinesSum,
    taxActive: true,
    baseAmount: cartLinesSum,
    taxAmount: tax,
    totalDue: cartLinesSum + tax,
  );
}
