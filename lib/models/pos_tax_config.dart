/// Branch tax settings from Odoo login (`pos_backend.branch`) / cached user data.
class PosTaxConfig {
  final bool active;
  /// VAT/Tax rate as percentage, e.g. 10 = 10%.
  final double percent;
  /// When true, product/cart line totals are **tax-inclusive** (customer pays [cart sum]).
  /// When false, lines are **tax-exclusive** and customer pays cartSum × (1 + percent/100).
  final bool inclusive;
  /// If false, POS UI + receipts/bills should not show VAT breakdown rows.
  final bool showOnReceipt;

  const PosTaxConfig({
    required this.active,
    required this.percent,
    required this.inclusive,
    required this.showOnReceipt,
  });

  static const PosTaxConfig disabled = PosTaxConfig(
    active: false,
    percent: 0,
    inclusive: false,
    showOnReceipt: true,
  );

  factory PosTaxConfig.fromLoginJson(Map<String, dynamic>? m) {
    if (m == null) return PosTaxConfig.disabled;
    final rawActive = m['tax_active'];
    final rawPct = m['tax_percent'];
    final rawInc = m['tax_inclusive'];
    final rawShow = m['tax_show_on_receipt'];
    final p = rawPct is num
        ? rawPct.toDouble()
        : double.tryParse(rawPct?.toString() ?? '') ?? 0.0;
    final active = rawActive == true || rawActive == 'true';
    final inclusive = rawInc == true || rawInc == 'true';
    final showOnReceipt =
        rawShow == null ? true : (rawShow == true || rawShow == 'true');
    final use = active && p > 0;
    return PosTaxConfig(
      active: use,
      percent: p.clamp(0.0, 100.0),
      inclusive: inclusive,
      showOnReceipt: showOnReceipt,
    );
  }

  String get percentLabel {
    if (percent == percent.roundToDouble()) {
      return percent.round().toString();
    }
    return percent.toStringAsFixed(2);
  }
}
