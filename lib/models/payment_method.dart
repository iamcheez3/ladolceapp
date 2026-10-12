class PaymentMethod {
  final int id;
  final String name;

  /// Paying with this method kicks the cash drawer (backend Configuration →
  /// Payment Methods → "Open cash drawer"). Servers older than 10 Oct 2026
  /// do not send the field; the app then keeps its old rule, "cash" in the
  /// name — the backend upgrade ticks exactly those methods too.
  final bool opensCashDrawer;

  PaymentMethod({
    required this.id,
    required this.name,
    bool? opensCashDrawer,
  }) : opensCashDrawer =
           opensCashDrawer ?? name.toLowerCase().contains('cash');

  /// Only cash can be more than the bill: the extra is given back as change.
  bool get isCash => name.toLowerCase().contains('cash');

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final drawer = json['open_cash_drawer'];
    return PaymentMethod(
      id: json['id'],
      name: json['name'] ?? '',
      opensCashDrawer: drawer is bool ? drawer : null,
    );
  }
}
