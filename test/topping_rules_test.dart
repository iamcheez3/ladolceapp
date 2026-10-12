import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/widgets/topping_picker.dart';

Topping _t(
  int id,
  String name, {
  int? group,
  int groupSeq = 0,
  bool multiple = false,
  bool required = false,
  bool isDefault = false,
  double price = 0,
}) => Topping(
  id: id,
  name: name,
  extraPrice: price,
  isDefault: isDefault,
  groupId: group,
  groupName: group == null ? '' : 'G$group',
  groupSequence: groupSeq,
  groupMultiple: group == null || multiple,
  groupRequired: group != null && required,
);

void main() {
  // Type (pick one, required, Hot default) / Size (pick one) / add-ons.
  final hot = _t(1, 'Hot', group: 1, groupSeq: 1, required: true, isDefault: true);
  final iced = _t(2, 'Iced', group: 1, groupSeq: 1, required: true);
  final m = _t(3, 'M', group: 2, groupSeq: 2);
  final l = _t(4, 'L', group: 2, groupSeq: 2, price: 5000);
  final shot = _t(5, 'Extra shot', price: 10000);
  final toppings = [shot, l, iced, m, hot];

  test('sections follow group order, add-ons last', () {
    final sections = ToppingRules.sections(toppings);
    expect(sections.map((s) => s.groupId), [1, 2, null]);
    expect(sections.first.options, [hot, iced]);
  });

  test('defaults are ticked when the picker opens', () {
    expect(ToppingRules.defaults(toppings), {hot.id});
  });

  test('a pick-one group keeps a single option', () {
    var picked = ToppingRules.toggle(toppings, {hot.id}, iced);
    expect(picked, {iced.id});
    picked = ToppingRules.toggle(toppings, picked, m);
    picked = ToppingRules.toggle(toppings, picked, l);
    expect(picked, {iced.id, l.id});
  });

  test('a required pick-one option cannot be unticked, others can', () {
    expect(ToppingRules.toggle(toppings, {hot.id}, hot), {hot.id});
    expect(ToppingRules.toggle(toppings, {m.id}, m), isEmpty);
  });

  test('add-ons and pick-many groups allow several options', () {
    final extra = _t(6, 'Oat milk', group: 3, multiple: true);
    final all = [...toppings, extra];
    var picked = ToppingRules.toggle(all, {}, shot);
    picked = ToppingRules.toggle(all, picked, extra);
    expect(picked, {shot.id, extra.id});
  });

  test('a required group with nothing picked blocks adding', () {
    expect(ToppingRules.missingRequired(toppings, {m.id}).map((s) => s.title), [
      'G1',
    ]);
    expect(ToppingRules.missingRequired(toppings, {hot.id}), isEmpty);
    expect(ToppingRules.hasRequired(toppings), isTrue);
    expect(ToppingRules.hasRequired([shot]), isFalse);
  });

  test('picked toppings come back in printing order', () {
    expect(ToppingRules.picked(toppings, {shot.id, l.id, hot.id}), [hot, l, shot]);
  });

  test('parses the grouped payload and an old server payload', () {
    final grouped = Topping.fromJson({
      'id': 9,
      'name': 'Hot',
      'name_lo': 'ຮ້ອນ',
      'extra_price': 0,
      'is_default': true,
      'group_id': 2,
      'group_name': 'Type',
      'group_name_lo': 'ປະເພດ',
      'group_sequence': 10,
      'group_type': 'single',
      'group_required': true,
    });
    expect(grouped.hasGroup, isTrue);
    expect(grouped.groupMultiple, isFalse);
    expect(grouped.groupRequired, isTrue);
    expect(grouped.isDefault, isTrue);

    final plain = Topping.fromJson({
      'id': 10,
      'name': 'Cheese',
      'extra_price': 5000,
      'group_id': false,
    });
    expect(plain.hasGroup, isFalse);
    expect(plain.groupMultiple, isTrue);

    final old = Topping.fromJson({'id': 11, 'name': 'Boba', 'extra_price': 0});
    expect(old.hasGroup, isFalse);
    expect(old.nameLo, '');
  });
}
