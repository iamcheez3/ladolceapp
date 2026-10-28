import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:ladolce/models/product.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/widgets/topping_picker.dart';

Topping opt(int id, String name, int? group,
    {String type = 'single', bool req = false, bool def = false, int gseq = 10, double price = 0}) {
  return Topping.fromJson({
    'id': id,
    'name': name,
    'name_lo': 'LO $name',
    'extra_price': price,
    'sequence': id,
    'is_default': def,
    'group_id': group ?? false,
    'group_name': group == null ? '' : 'G$group',
    'group_name_lo': group == null ? '' : 'GLO$group',
    'group_sequence': gseq,
    'group_type': type,
    'group_required': req,
  });
}

void main() {
  // Server order on purpose scrambled: add-on first, Size before Type.
  final extraShot = opt(1, 'Extra shot', null, price: 10000);
  final sizeM = opt(2, 'Size M', 30, req: true, def: true, gseq: 30);
  final sizeL = opt(3, 'Size L', 30, req: true, gseq: 30, price: 5000);
  final hot = opt(4, 'Hot', 10, req: true, def: true, gseq: 10);
  final iced = opt(5, 'Iced', 10, req: true, gseq: 10);
  final sweet = opt(6, 'Sweet', 20, gseq: 20);
  final bitter = opt(7, 'Bitter', 20, gseq: 20);
  final oat = opt(8, 'Oat milk', null, price: 8000);
  final all = [extraShot, sizeM, sizeL, hot, iced, sweet, bitter, oat];
  List<int> ids(List<Topping> l) => l.map((t) => t.id).toList();

  test('sections: groups in group order, plain add-ons last', () {
    final s = ToppingRules.sections(all);
    expect(s.map((x) => x.groupId).toList(), [10, 20, 30, null]);
    expect(ids(s.last.options), [1, 8]);
    expect(s.first.single && s.first.required, isTrue);
  });

  test('defaults: Hot + Size M', () {
    expect(ids(ToppingRules.defaults(all)), [4, 2]);
  });

  test('pick-one swaps; required pick-one cannot be unticked', () {
    var sel = ToppingRules.defaults(all);
    sel = ToppingRules.toggle(all, sel, iced);
    expect(ids(sel), [5, 2], reason: 'Iced replaces Hot');
    sel = ToppingRules.toggle(all, sel, iced);
    expect(ids(sel), [5, 2], reason: 'tapping the chosen required option keeps it');
    sel = ToppingRules.toggle(all, sel, sizeL);
    expect(ids(sel), [5, 3]);
  });

  test('optional pick-one can be unticked; add-ons are pick-many', () {
    var sel = ToppingRules.toggle(all, [], sweet);
    sel = ToppingRules.toggle(all, sel, bitter);
    expect(ids(sel), [7]);
    sel = ToppingRules.toggle(all, sel, bitter);
    expect(sel, isEmpty);
    sel = ToppingRules.toggle(all, sel, oat);
    sel = ToppingRules.toggle(all, sel, extraShot);
    expect(ids(sel), [1, 8], reason: 'both add-ons, in picker order');
  });

  test('missing required groups and quick add', () {
    expect(ToppingRules.missing(all, []).map((s) => s.groupId), [10, 30]);
    expect(ToppingRules.missing(all, ToppingRules.defaults(all)), isEmpty);
    expect(ToppingRules.canQuickAdd(all), isTrue);
    final noDefault = [opt(9, 'S', 40, req: true), opt(10, 'L', 40, req: true)];
    expect(ToppingRules.canQuickAdd(noDefault), isFalse);
  });

  test('old server payload (id, name, extra_price) = plain add-on', () {
    final t = Topping.fromJson({'id': 1, 'name': 'Extra shot', 'extra_price': 10000});
    expect(t.groupId, isNull);
    expect(t.isSingleChoice, isFalse);
    expect(ToppingRules.defaults([t]), isEmpty);
    expect(ToppingRules.missing([t], []), isEmpty);
    expect(Topping.fromJson(t.toJson()).name, 'Extra shot');
  });

  test('names follow the app language', () {
    Product.useLaoNames = true;
    expect(hot.displayName, 'LO Hot');
    expect(hot.groupDisplayName, 'GLO10');
    Product.useLaoNames = false;
    expect(hot.displayName, 'Hot');
  });

  testWidgets('picker: required group shows, tap swaps radio', (tester) async {
    var sel = ToppingRules.defaults(all);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ToppingPicker(
              toppings: all,
              selected: sel,
              accent: Colors.indigo,
              addOnsTitle: 'Add-ons',
              cardStyle: true,
              onChanged: (n) => setState(() => sel = n),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('G10'), findsOneWidget);
    expect(find.text('Add-ons'), findsOneWidget);
    expect(find.text('Pick 1'), findsNWidgets(3));
    await tester.tap(find.text('Size L'));
    await tester.pump();
    expect(ids(sel), [4, 3]);
  });
}
