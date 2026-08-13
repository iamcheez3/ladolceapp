import 'dart:convert';
import 'dart:typed_data';
import 'topping.dart';
import 'combo.dart';

class Product {
  final int id;
  final String name;
  final double price;
  final String category;
  final String? imageUrl;
  final String? imageBase64;
  final double? qtyAvailable;
  final String? defaultCode;
  final List<Topping> toppings;
  final double? promotionPrice;

  static bool disablePromotionPrice = false;
  static bool isCustomerMode = false;

  double get effectivePrice {
    if (isCustomerMode) {
      return promotionPrice ?? price;
    }
    return (disablePromotionPrice ? null : promotionPrice) ?? price;
  }
  
  // Custom Combo Support
  final bool isCombo;
  final List<ComboLine>? comboLines;
  
  // UI Helpers
  final int colorCode;

  /// When true, customer self-order shows this item as run out and cannot add to cart.
  final bool blockSelfOrder;

  final bool isRecommended;
  final String? recommendedImageBase64;

  // Point Redeem Feature
  final bool isRedeemable;
  final int pointPrice;
  final DateTime? redeemStartDate;
  final DateTime? redeemEndDate;

  /// Odoo often sends [category] as a path like "All / Saleable / Office Furniture".
  /// POS and customer UIs only need the leaf name for tabs and labels.
  static String leafCategoryName(Object? raw) {
    if (raw == null) return 'Uncategorized';
    final s = raw.toString().trim();
    if (s.isEmpty) return 'Uncategorized';
    if (s.contains(' / ')) {
      final parts = s.split(' / ').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.last;
    }
    if (s.contains('/')) {
      final parts = s.split('/').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.last;
    }
    return s;
  }

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.imageUrl,
    this.imageBase64,
    this.qtyAvailable,
    this.defaultCode,
    this.toppings = const [],
    this.isCombo = false,
    this.comboLines,
    this.colorCode = 0xFF1E3A8A, // Default Dark Blue
    this.blockSelfOrder = false,
    this.isRecommended = false,
    this.recommendedImageBase64,
    this.promotionPrice,
    this.isRedeemable = false,
    this.pointPrice = 0,
    this.redeemStartDate,
    this.redeemEndDate,
  });

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    List<Topping> parsedToppings = [];
    if (json['toppings'] != null) {
      parsedToppings = (json['toppings'] as List).map((t) => Topping.fromJson(t)).toList();
    }

    String? rawUrl = json['image_url'];
    if (rawUrl != null) {
      rawUrl = rawUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
    }

    return Product(
      id: json['id'],
      name: json['name'] ?? 'Unnamed Product',
      price: (json['list_price'] ?? 0.0).toDouble(),
      category: leafCategoryName(json['category'] ?? 'Uncategorized'),
      imageUrl: rawUrl,
      imageBase64: json['image_base64'] is String ? json['image_base64'] : null,
      qtyAvailable: json['qty_available']?.toDouble(),
      defaultCode: json['default_code'] is String ? json['default_code'] : null,
      toppings: parsedToppings,
      isCombo: false,
      blockSelfOrder: _parseBool(json['block_self_order']),
      isRecommended: _parseBool(json['is_recommended_self_order']),
      recommendedImageBase64: json['recommended_image_base64'] is String ? json['recommended_image_base64'] : null,
      promotionPrice: json['promotion_price'] != null ? (json['promotion_price'] as num).toDouble() : null,
      isRedeemable: _parseBool(json['is_redeemable']),
      pointPrice: json['point_price'] != null ? (json['point_price'] as num).toInt() : 0,
      redeemStartDate: json['redeem_start_date'] != null ? DateTime.tryParse(json['redeem_start_date'].toString()) : null,
      redeemEndDate: json['redeem_end_date'] != null ? DateTime.tryParse(json['redeem_end_date'].toString()) : null,
    );
  }

  // Factory to tightly couple a Combo object into a valid UI Product format
  factory Product.fromCombo(Combo combo) {
    return Product(
      id: -combo.id, // Store combo ID as negative inside the product id
      name: combo.name,
      price: combo.price,
      category: 'Combos',
      isCombo: true,
      comboLines: combo.lines,
      colorCode: combo.colorCode,
      blockSelfOrder: false,
    );
  }

  // Lazy Cached Base64 Decoded Image Bytes
  Uint8List? _decodedImageBytes;
  bool _decodedImageBytesInit = false;
  Uint8List? get decodedImageBytes {
    if (!_decodedImageBytesInit) {
      if (imageBase64 != null && imageBase64!.isNotEmpty) {
        try {
          _decodedImageBytes = base64Decode(imageBase64!);
        } catch (_) {
          _decodedImageBytes = null;
        }
      }
      _decodedImageBytesInit = true;
    }
    return _decodedImageBytes;
  }

  Uint8List? _decodedRecommendedImageBytes;
  bool _decodedRecommendedImageBytesInit = false;
  Uint8List? get decodedRecommendedImageBytes {
    if (!_decodedRecommendedImageBytesInit) {
      if (recommendedImageBase64 != null && recommendedImageBase64!.isNotEmpty) {
        try {
          _decodedRecommendedImageBytes = base64Decode(recommendedImageBase64!);
        } catch (_) {
          _decodedRecommendedImageBytes = null;
        }
      }
      _decodedRecommendedImageBytesInit = true;
    }
    return _decodedRecommendedImageBytes;
  }
}

class Category {
  final String id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });
}
