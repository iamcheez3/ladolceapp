import 'package:flutter/material.dart';

import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../utils/l10n_ext.dart';

/// One heading of the picker: a topping group, or the plain add-ons.
class ToppingSection {
  final int? groupId;
  final Topping? first;
  final List<Topping> options;

  ToppingSection(this.groupId, this.first, this.options);

  bool get isGroup => groupId != null;
  bool get multiple => first?.groupMultiple ?? true;
  bool get required => first?.groupRequired ?? false;
  String get title => first?.groupDisplayName ?? '';
}

/// What the picker allows, kept apart from the widget so it can be tested.
///
/// A pick-one group holds at most one option; a required group must hold one
/// before the item can be added; options marked `is_default` start ticked.
class ToppingRules {
  ToppingRules._();

  /// Groups in group order, then the plain add-ons.
  static List<ToppingSection> sections(List<Topping> toppings) {
    final byGroup = <int?, List<Topping>>{};
    for (final t in Topping.sorted(toppings)) {
      byGroup.putIfAbsent(t.groupId, () => []).add(t);
    }
    final sections = [
      for (final e in byGroup.entries)
        if (e.key != null) ToppingSection(e.key, e.value.first, e.value),
    ];
    final addOns = byGroup[null];
    if (addOns != null) sections.add(ToppingSection(null, null, addOns));
    return sections;
  }

  /// Options ticked when the picker opens.
  static Set<int> defaults(List<Topping> toppings) {
    final picked = <int>{};
    for (final s in sections(toppings)) {
      final defaults = s.options.where((t) => t.isDefault);
      if (!s.isGroup) continue;
      if (s.multiple) {
        picked.addAll(defaults.map((t) => t.id));
      } else if (defaults.isNotEmpty) {
        picked.add(defaults.first.id);
      }
    }
    return picked;
  }

  /// [selected] after tapping [option].
  static Set<int> toggle(
    List<Topping> toppings,
    Set<int> selected,
    Topping option,
  ) {
    final next = {...selected};
    if (next.contains(option.id)) {
      // A required pick-one group always keeps an answer once it has one.
      if (option.hasGroup && !option.groupMultiple && option.groupRequired) {
        return next;
      }
      next.remove(option.id);
      return next;
    }
    if (option.hasGroup && !option.groupMultiple) {
      next.removeAll(
        toppings.where((t) => t.groupId == option.groupId).map((t) => t.id),
      );
    }
    next.add(option.id);
    return next;
  }

  /// Required groups with nothing picked, in picker order.
  static List<ToppingSection> missingRequired(
    List<Topping> toppings,
    Set<int> selected,
  ) => [
    for (final s in sections(toppings))
      if (s.isGroup &&
          s.required &&
          !s.options.any((t) => selected.contains(t.id)))
        s,
  ];

  static bool hasRequired(List<Topping> toppings) =>
      toppings.any((t) => t.hasGroup && t.groupRequired);

  /// The picked toppings, in printing order.
  static List<Topping> picked(List<Topping> toppings, Set<int> selected) =>
      Topping.sorted(toppings.where((t) => selected.contains(t.id)));
}

String _price(BuildContext context, double extra) =>
    extra > 0 ? '+₭${extra.toStringAsFixed(0)}' : context.l10n.free;

/// Grouped topping picker: one heading per group ("Milk  Pick 1  Required"),
/// options as a 3-column grid (2 on very narrow screens).
class ToppingPicker extends StatelessWidget {
  final List<Topping> toppings;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  const ToppingPicker({
    super.key,
    required this.toppings,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sections = ToppingRules.sections(toppings);
    final anyGroup = sections.any((s) => s.isGroup);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 300 ? 2 : 3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in sections) ...[
              if (s.isGroup || anyGroup) _SectionHeader(section: s),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 14),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 84,
                ),
                itemCount: s.options.length,
                itemBuilder: (context, i) {
                  final t = s.options[i];
                  return _OptionCard(
                    topping: t,
                    pickOne: s.isGroup && !s.multiple,
                    isSelected: selected.contains(t.id),
                    onTap: () =>
                        onChanged(ToppingRules.toggle(toppings, selected, t)),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final ToppingSection section;

  const _SectionHeader({required this.section});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, Color fg, Color bg) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              section.isGroup ? section.title : context.l10n.addOns,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: LaDolcePosUi.navy,
              ),
            ),
          ),
          if (section.isGroup)
            chip(
              section.multiple ? context.l10n.pickMany : context.l10n.pickOne,
              const Color(0xFF475569),
              const Color(0xFFE2E8F0),
            ),
          if (section.required)
            chip(
              context.l10n.requiredLabel,
              const Color(0xFFEA580C),
              const Color(0xFFFFEDD5),
            ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final Topping topping;
  final bool pickOne;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.topping,
    required this.pickOne,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = pickOne
        ? (isSelected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded)
        : (isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline);
    return Material(
      color: isSelected ? const Color(0xFFEEF1FB) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? LaDolcePosUi.navy : LaDolcePosUi.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      topping.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: LaDolcePosUi.text,
                      ),
                    ),
                  ),
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? LaDolcePosUi.navy
                        : Colors.grey.shade400,
                  ),
                ],
              ),
              // Full card width, so "+₭10000" never wraps beside the icon.
              Text(
                _price(context, topping.extraPrice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cashier sheet: "Select Toppings for Americano". Returns the picked
/// toppings (empty for "Add Without Toppings"), or null when dismissed.
Future<List<Topping>?> showToppingPickerSheet(
  BuildContext context, {
  required String title,
  required List<Topping> toppings,
}) {
  var selected = ToppingRules.defaults(toppings);
  final hasRequired = ToppingRules.hasRequired(toppings);
  return showModalBottomSheet<List<Topping>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final missing = ToppingRules.missingRequired(toppings, selected);
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              22,
              20,
              16 + LaDolcePosUi.modalBottomPadding(sheetContext),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: ToppingPicker(
                      toppings: toppings,
                      selected: selected,
                      onChanged: (next) => setSheetState(() => selected = next),
                    ),
                  ),
                ),
                if (missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      sheetContext.l10n.pleaseChooseGroups(
                        missing.map((s) => s.title).join(', '),
                      ),
                      style: const TextStyle(
                        color: Color(0xFFEA580C),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (!hasRequired) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, <Topping>[]),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            sheetContext.l10n.addWithoutToppings,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: missing.isEmpty
                            ? () => Navigator.pop(
                                sheetContext,
                                ToppingRules.picked(toppings, selected),
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LaDolcePosUi.navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(sheetContext.l10n.addToOrder),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
