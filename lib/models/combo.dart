import '../utils/bilingual_name.dart';

class ComboLine {
  final int id;
  final int productId;
  final String productName;
  final int qty;

  ComboLine({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
  });

  factory ComboLine.fromJson(Map<String, dynamic> json) {
    return ComboLine(
      id: json['id'],
      productId: json['product_id'],
      productName: bilingualName(json, fallback: 'Unknown'),
      qty: json['qty'] ?? 1,
    );
  }
}

class Combo {
  final int id;
  final String name;
  final double price;
  final List<ComboLine> lines;

  // UI Helpers mapped for POS Grid compatibility
  final int colorCode;

  Combo({
    required this.id,
    required this.name,
    required this.price,
    this.lines = const [],
    this.colorCode = 0xFF581C87, // Default Dark Purple for combos
  });

  factory Combo.fromJson(Map<String, dynamic> json) {
    List<ComboLine> parsedLines = [];
    if (json['lines'] != null) {
      parsedLines = (json['lines'] as List).map((l) => ComboLine.fromJson(l)).toList();
    }
    
    return Combo(
      id: json['id'],
      name: json['name'] ?? 'Unnamed Combo',
      price: (json['price'] ?? 0.0).toDouble(),
      lines: parsedLines,
    );
  }
}
