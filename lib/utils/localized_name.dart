/// Display language for labels that come from the backend.
///
/// Product and order-line names are Odoo data, not UI strings, so they cannot
/// live in the ARB catalogue: every record carries an English value plus an
/// optional Lao counterpart (`name_lo` / `product_name_lo`). This holds the
/// language those values should be rendered in, kept in step with the app
/// locale by `main.dart`.
///
/// It mirrors the static-flag pattern already used for `Product.isCustomerMode`
/// and `Product.disablePromotionPrice`, so a name can be resolved from models
/// and printer payloads that have no `BuildContext`.
class DisplayLanguage {
  DisplayLanguage._();

  static String code = 'en';

  static bool get isLao => code == 'lo';
}

/// Picks the Lao label when the app is in Lao and one was actually saved.
///
/// The backend already falls back to the English name when a product has no
/// Lao translation, so a blank or identical `*_lo` value is expected rather
/// than an error — never let it blank out the label.
String localizedName(
  String? name,
  String? nameLo, {
  String fallback = 'Item',
}) {
  if (DisplayLanguage.isLao) {
    final lo = nameLo?.trim() ?? '';
    if (lo.isNotEmpty) return lo;
  }
  final en = name?.trim() ?? '';
  return en.isNotEmpty ? en : fallback;
}

/// [localizedName] for the order-line maps returned by the order endpoints
/// (receipt, open_tickets, my_orders, self_orders/pending, rider/orders,
/// refund), which all carry `product_name` and `product_name_lo`.
String localizedLineName(Map<dynamic, dynamic> line, {String fallback = 'Item'}) {
  return localizedName(
    line['product_name']?.toString(),
    line['product_name_lo']?.toString(),
    fallback: fallback,
  );
}
