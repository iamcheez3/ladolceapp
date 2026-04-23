class Topping {
  final int id;
  final String name;
  final double extraPrice;

  Topping({
    required this.id,
    required this.name,
    this.extraPrice = 0.0,
  });

  factory Topping.fromJson(Map<String, dynamic> json) {
    return Topping(
      id: json['id'],
      name: json['name'] ?? 'Unknown Topping',
      extraPrice: (json['extra_price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'extra_price': extraPrice,
    };
  }
}
