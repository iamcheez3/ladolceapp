class PaymentMethod {
  final int id;
  final String name;

  /// Paying with this method opens the cash drawer (backend checkbox).
  /// Older servers do not send it: then any method named "cash".
  final bool opensCashDrawer;

  PaymentMethod({
    required this.id,
    required this.name,
    bool? opensCashDrawer,
  }) : opensCashDrawer = opensCashDrawer ?? name.toLowerCase().contains('cash');

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    final raw = json['open_cash_drawer'];
    return PaymentMethod(
      id: json['id'],
      name: json['name'] ?? '',
      opensCashDrawer: raw is bool ? raw : null,
    );
  }
}
