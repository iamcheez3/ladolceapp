import 'product.dart';

class Topping {
  final int id;
  final String name;

  /// Lao name; the server falls back to [name] when it is blank.
  final String? nameLo;
  final double extraPrice;
  final int sequence;

  /// Pre-selected when the item opens.
  final bool isDefault;

  /// Topping group ("Type", "Taste", "Size"...). Null = plain add-on, shown
  /// as a pick-many list like before groups existed.
  final int? groupId;
  final String groupName;
  final String? groupNameLo;
  final int groupSequence;

  /// 'single' (pick one) or 'multiple' (pick many).
  final String groupType;
  final bool groupRequired;

  Topping({
    required this.id,
    required this.name,
    this.nameLo,
    this.extraPrice = 0.0,
    this.sequence = 0,
    this.isDefault = false,
    this.groupId,
    this.groupName = '',
    this.groupNameLo,
    this.groupSequence = 0,
    this.groupType = 'multiple',
    this.groupRequired = false,
  });

  bool get isSingleChoice => groupId != null && groupType == 'single';

  /// Name in the app language (same switch as [Product.displayName]).
  String get displayName => _pick(name, nameLo);

  String get groupDisplayName => _pick(groupName, groupNameLo);

  static String _pick(String english, String? lao) {
    if (Product.useLaoNames) {
      final l = lao?.trim() ?? '';
      if (l.isNotEmpty) return l;
    }
    return english;
  }

  // Old servers and old caches only send id / name / extra_price.
  factory Topping.fromJson(Map<String, dynamic> json) {
    final rawGroup = json['group_id'];
    final groupId = rawGroup is int
        ? rawGroup
        : (rawGroup is List && rawGroup.isNotEmpty && rawGroup.first is int)
            ? rawGroup.first as int
            : null;
    return Topping(
      id: json['id'],
      name: json['name'] ?? 'Unknown Topping',
      nameLo: json['name_lo'] is String ? json['name_lo'] as String : null,
      extraPrice: (json['extra_price'] ?? 0.0).toDouble(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      isDefault: json['is_default'] == true,
      groupId: (groupId != null && groupId > 0) ? groupId : null,
      groupName: json['group_name'] is String ? json['group_name'] as String : '',
      groupNameLo:
          json['group_name_lo'] is String ? json['group_name_lo'] as String : null,
      groupSequence: (json['group_sequence'] as num?)?.toInt() ?? 0,
      groupType: json['group_type'] == 'single' ? 'single' : 'multiple',
      groupRequired: json['group_required'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_lo': nameLo,
      'extra_price': extraPrice,
      'sequence': sequence,
      'is_default': isDefault,
      'group_id': groupId ?? false,
      'group_name': groupName,
      'group_name_lo': groupNameLo,
      'group_sequence': groupSequence,
      'group_type': groupType,
      'group_required': groupRequired,
    };
  }
}

/// A heading in the topping picker, managed in Items → Toppings → Groups.
class ToppingGroup {
  final int id;
  final String name;
  final String? nameLo;
  final int sequence;

  /// 'single' (pick one) or 'multiple' (pick many).
  final String selectionType;
  final bool required;

  ToppingGroup({
    required this.id,
    required this.name,
    this.nameLo,
    this.sequence = 0,
    this.selectionType = 'single',
    this.required = false,
  });

  bool get isSingleChoice => selectionType == 'single';

  String get displayName => Topping._pick(name, nameLo);

  factory ToppingGroup.fromJson(Map<String, dynamic> json) {
    return ToppingGroup(
      id: json['id'],
      name: json['name'] ?? '',
      nameLo: json['name_lo'] is String ? json['name_lo'] as String : null,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      selectionType: json['selection_type'] == 'multiple' ? 'multiple' : 'single',
      required: json['required'] == true,
    );
  }
}
