import '../models/product.dart';

/// Picks the Lao or English variant of a bilingual label carried by an API
/// payload.
///
/// The backend ships both spellings side by side on every response that names a
/// product — `product_name` / `product_name_lo` on order lines, vouchers and
/// combo lines — and already applies the English fallback server-side, so the
/// Lao key is never null or empty for a product that has no translation. The
/// `?? english` here only guards against an older backend that predates the
/// field.
///
/// Because both names arrive together, switching language needs no refetch and
/// no cache invalidation: the next rebuild simply reads the other key.
String bilingualName(
  Map<dynamic, dynamic> json, {
  String field = 'product_name',
  String fallback = '',
}) {
  if (Product.useLaoNames) {
    final lao = json['${field}_lo']?.toString().trim() ?? '';
    if (lao.isNotEmpty) return lao;
  }
  final english = json[field]?.toString().trim() ?? '';
  return english.isNotEmpty ? english : fallback;
}
