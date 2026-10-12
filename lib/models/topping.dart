import '../utils/localized_name.dart';

/// A topping / choice as `/api/pos/toppings` and `/api/products` send it.
///
/// Since the 10 Oct backend each topping carries its group inline
/// (`group_id`, `group_name`, `group_type`, `group_required`), so the picker
/// can lay out "Type / Taste / Size" without a second request. A topping with
/// no group is a plain add-on. Older servers send only id, name, extra_price;
/// every other field then falls back to "plain add-on".
class Topping {
  final int id;
  final String name;

  /// Lao label (`name_lo`); the backend echoes [name] when none is saved.
  final String nameLo;

  final double extraPrice;
  final int sequence;

  /// Ticked when the picker opens.
  final bool isDefault;

  final int? groupId;
  final String groupName;
  final String groupNameLo;
  final int groupSequence;

  /// `group_type == 'multiple'`: any number of options may be picked.
  final bool groupMultiple;

  /// One option of the group must be picked before the item can be added.
  final bool groupRequired;

  Topping({
    required this.id,
    required this.name,
    this.nameLo = '',
    this.extraPrice = 0.0,
    this.sequence = 10,
    this.isDefault = false,
    this.groupId,
    this.groupName = '',
    this.groupNameLo = '',
    this.groupSequence = 0,
    this.groupMultiple = true,
    this.groupRequired = false,
  });

  bool get hasGroup => groupId != null;

  /// Name in the app's current language.
  String get displayName => localizedName(name, nameLo, fallback: name);

  String get groupDisplayName =>
      localizedName(groupName, groupNameLo, fallback: groupName);

  /// Odoo sends `false` for an empty many2one.
  static int? _optionalId(dynamic v) {
    if (v is int) return v > 0 ? v : null;
    if (v is num) return v > 0 ? v.toInt() : null;
    final parsed = int.tryParse(v?.toString() ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static String _text(dynamic v) =>
      (v == null || v == false) ? '' : v.toString();

  factory Topping.fromJson(Map<String, dynamic> json) {
    final groupId = _optionalId(json['group_id']);
    return Topping(
      id: json['id'],
      name: json['name'] ?? 'Unknown Topping',
      nameLo: _text(json['name_lo']),
      extraPrice: (json['extra_price'] ?? 0.0).toDouble(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 10,
      isDefault: json['is_default'] == true,
      groupId: groupId,
      groupName: groupId == null ? '' : _text(json['group_name']),
      groupNameLo: groupId == null ? '' : _text(json['group_name_lo']),
      groupSequence: (json['group_sequence'] as num?)?.toInt() ?? 0,
      groupMultiple: groupId == null || json['group_type'] != 'single',
      groupRequired: groupId != null && json['group_required'] == true,
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
      'group_type': groupMultiple ? 'multiple' : 'single',
      'group_required': groupRequired,
    };
  }

  /// Grouped options first (in group order), then plain add-ons — the order
  /// the backend uses for line names, so paper and screen read alike.
  static List<Topping> sorted(Iterable<Topping> toppings) {
    final list = toppings.toList();
    list.sort((a, b) {
      final byGroup = (a.hasGroup ? 0 : 1).compareTo(b.hasGroup ? 0 : 1);
      if (byGroup != 0) return byGroup;
      final bySeq = a.groupSequence.compareTo(b.groupSequence);
      if (bySeq != 0) return bySeq;
      final byGroupId = (a.groupId ?? 0).compareTo(b.groupId ?? 0);
      if (byGroupId != 0) return byGroupId;
      final byOwnSeq = a.sequence.compareTo(b.sequence);
      if (byOwnSeq != 0) return byOwnSeq;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  bool operator ==(Object other) => other is Topping && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A heading in the topping picker, e.g. "Type" (Hot / Iced) or "Size".
/// Backend: `/api/pos/topping_groups`.
class ToppingGroup {
  final int id;
  final String name;
  final String nameLo;
  final int sequence;
  final bool multiple;
  final bool required;

  ToppingGroup({
    required this.id,
    required this.name,
    this.nameLo = '',
    this.sequence = 10,
    this.multiple = false,
    this.required = false,
  });

  String get displayName => localizedName(name, nameLo, fallback: name);

  factory ToppingGroup.fromJson(Map<String, dynamic> json) {
    return ToppingGroup(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      nameLo: (json['name_lo'] == false ? '' : json['name_lo'] ?? '')
          .toString(),
      sequence: (json['sequence'] as num?)?.toInt() ?? 10,
      multiple: json['selection_type'] == 'multiple',
      required: json['required'] == true,
    );
  }
}
