import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PosDiscountOption {
  final String id;
  final String type; // 'percentage' or 'value'
  final double? value; // null means manual value / custom value
  final String name; // e.g. "Discount 10%", "Discount 15%", "Discount Value"

  PosDiscountOption({
    required this.id,
    required this.type,
    this.value,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'value': value,
        'name': name,
      };

  factory PosDiscountOption.fromJson(Map<String, dynamic> json) => PosDiscountOption(
        id: json['id'] as String,
        type: json['type'] as String,
        value: json['value'] != null ? (json['value'] as num).toDouble() : null,
        name: json['name'] as String,
      );

  bool get isManual => value == null;
}

class PosDiscountConfig {
  final bool enabled;
  final List<PosDiscountOption> options;

  const PosDiscountConfig({
    required this.enabled,
    required this.options,
  });

  static const PosDiscountConfig disabled = PosDiscountConfig(
    enabled: false,
    options: [],
  );

  static const String _keyEnabled = 'pos_discount_enabled';
  static const String _keyOptionsJson = 'pos_discount_options_json';

  static Future<PosDiscountConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final optionsJson = prefs.getString(_keyOptionsJson);
    List<PosDiscountOption> options = [];
    if (optionsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(optionsJson);
        options = decoded.map((item) => PosDiscountOption.fromJson(item)).toList();
      } catch (_) {
        options = _defaultOptions();
      }
    } else {
      options = _defaultOptions();
    }
    return PosDiscountConfig(
      enabled: enabled,
      options: options,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
    final optionsJson = json.encode(options.map((o) => o.toJson()).toList());
    await prefs.setString(_keyOptionsJson, optionsJson);
  }

  static List<PosDiscountOption> _defaultOptions() {
    return [
      PosDiscountOption(id: '1', type: 'percentage', value: 10.0, name: 'Discount 10%'),
      PosDiscountOption(id: '2', type: 'percentage', value: 15.0, name: 'Discount 15%'),
      PosDiscountOption(id: '3', type: 'value', value: null, name: 'Discount (Value)'),
    ];
  }
}
