import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import '../models/topping.dart';
import '../utils/money.dart';

/// One heading of the picker: a topping group ("Type", "Size"...) or, with a
/// null [groupId], the plain add-ons that have no group.
class ToppingSection {
  final int? groupId;
  final String title;
  final bool single;
  final bool required;
  final List<Topping> options;

  const ToppingSection({
    required this.groupId,
    required this.title,
    required this.single,
    required this.required,
    required this.options,
  });
}

/// Selection rules shared by the POS and the customer self-order screens.
class ToppingRules {
  ToppingRules._();

  /// [toppings] in picker order: groups by their order, plain add-ons last.
  static List<Topping> ordered(List<Topping> toppings) {
    final indexed = toppings.asMap().entries.toList();
    indexed.sort((a, b) {
      final ta = a.value, tb = b.value;
      final ga = ta.groupId == null ? 1 : 0, gb = tb.groupId == null ? 1 : 0;
      if (ga != gb) return ga - gb;
      if (ta.groupSequence != tb.groupSequence) {
        return ta.groupSequence - tb.groupSequence;
      }
      if ((ta.groupId ?? 0) != (tb.groupId ?? 0)) {
        return (ta.groupId ?? 0) - (tb.groupId ?? 0);
      }
      if (ta.sequence != tb.sequence) return ta.sequence - tb.sequence;
      return a.key - b.key;
    });
    return [for (final e in indexed) e.value];
  }

  static List<ToppingSection> sections(List<Topping> toppings) {
    final out = <ToppingSection>[];
    for (final t in ordered(toppings)) {
      if (out.isEmpty || out.last.groupId != t.groupId) {
        out.add(ToppingSection(
          groupId: t.groupId,
          title: t.groupId == null ? '' : t.groupDisplayName,
          single: t.isSingleChoice,
          required: t.groupId != null && t.groupRequired,
          options: [t],
        ));
      } else {
        out.last.options.add(t);
      }
    }
    return out;
  }

  static bool hasGroups(List<Topping> toppings) =>
      toppings.any((t) => t.groupId != null);

  /// What is ticked when the item opens: the admin's defaults (one per
  /// pick-one group).
  static List<Topping> defaults(List<Topping> toppings) {
    final picked = <Topping>[];
    for (final s in sections(toppings)) {
      final defs = s.options.where((t) => t.isDefault);
      picked.addAll(s.single ? defs.take(1) : defs);
    }
    return picked;
  }

  /// Tap on [t]. A pick-one group swaps its option; a required pick-one
  /// option cannot be unticked (pick another one instead).
  static List<Topping> toggle(
    List<Topping> all,
    List<Topping> selected,
    Topping t,
  ) {
    final isOn = selected.any((s) => s.id == t.id);
    final next = <Topping>[];
    if (isOn) {
      if (t.isSingleChoice && t.groupRequired) return selected;
      next.addAll(selected.where((s) => s.id != t.id));
    } else {
      next.addAll(selected.where(
        (s) => !(t.isSingleChoice && s.groupId == t.groupId),
      ));
      next.add(t);
    }
    final ids = next.map((s) => s.id).toSet();
    // Keep the picker order so tickets and receipts read the same way.
    return [for (final o in ordered(all)) if (ids.contains(o.id)) o];
  }

  /// Required groups that still have nothing chosen.
  static List<ToppingSection> missing(
    List<Topping> all,
    List<Topping> selected,
  ) {
    final ids = selected.map((s) => s.id).toSet();
    return [
      for (final s in sections(all))
        if (s.required && !s.options.any((o) => ids.contains(o.id))) s,
    ];
  }

  /// True when the item can go straight to the cart without the picker
  /// (quick "+" buttons): every required group has a default.
  static bool canQuickAdd(List<Topping> all) =>
      missing(all, defaults(all)).isEmpty;
}

/// Grouped topping picker: radio-style rows for pick-one groups, ticks for
/// pick-many groups and for plain add-ons.
class ToppingPicker extends StatelessWidget {
  final List<Topping> toppings;
  final List<Topping> selected;
  final ValueChanged<List<Topping>> onChanged;

  /// Big rounded cards (customer app) instead of compact rows (POS).
  final bool cardStyle;
  final Color accent;

  /// Heading for toppings without a group. Shown when there are groups too,
  /// or always when [alwaysShowAddOnsTitle] is set.
  final String addOnsTitle;
  final bool alwaysShowAddOnsTitle;

  const ToppingPicker({
    super.key,
    required this.toppings,
    required this.selected,
    required this.onChanged,
    required this.accent,
    required this.addOnsTitle,
    this.cardStyle = false,
    this.alwaysShowAddOnsTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = ToppingRules.sections(toppings);
    final grouped = sections.any((s) => s.groupId != null);
    final ids = selected.map((s) => s.id).toSet();
    final children = <Widget>[];

    for (final s in sections) {
      final title = s.groupId == null ? addOnsTitle : s.title;
      final showTitle = s.groupId != null || grouped || alwaysShowAddOnsTitle;
      if (showTitle) {
        final chosen = s.options.any((o) => ids.contains(o.id));
        children.add(Padding(
          padding: EdgeInsets.only(
            top: children.isEmpty ? 0 : (cardStyle ? 20 : 12),
            bottom: cardStyle ? 12 : 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: cardStyle ? 18 : 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              if (s.groupId != null && s.single)
                _chip(l10n?.toppingPickOne ?? 'Pick 1', Colors.blueGrey),
              if (s.required) ...[
                const SizedBox(width: 6),
                chosen
                    ? Icon(Icons.check_circle, size: 18, color: Colors.green.shade600)
                    : _chip(l10n?.toppingRequired ?? 'Required', Colors.deepOrange),
              ],
            ],
          ),
        ));
      }
      // Options in a grid (3 columns, 2 on very narrow screens) so a few
      // groups do not make the sheet very long.
      children.add(LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 330 ? 3 : 2;
        const gap = 8.0;
        final width = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in s.options)
              SizedBox(
                width: width,
                child: _tile(context, t, ids.contains(t.id), s.single),
              ),
          ],
        );
      }));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  void _tap(Topping t) => onChanged(ToppingRules.toggle(toppings, selected, t));

  String _price(Topping t) => '+₭${money(t.extraPrice)}';

  IconData _icon(bool isOn, bool single) {
    if (single) {
      return isOn ? Icons.radio_button_checked : Icons.radio_button_unchecked;
    }
    return isOn ? Icons.check_circle : Icons.add_circle_outline;
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      );

  /// One option as a grid tile: name (up to 2 lines), price or "Free" under
  /// it (so tiles in a row line up), radio/tick at the top right.
  Widget _tile(BuildContext context, Topping t, bool isOn, bool single) {
    final l10n = AppLocalizations.of(context);
    final radius = BorderRadius.circular(cardStyle ? 16 : 12);
    return Material(
      color: isOn ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: () => _tap(t),
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(minHeight: cardStyle ? 64 : 56),
          padding: EdgeInsets.fromLTRB(10, cardStyle ? 10 : 8, 6, cardStyle ? 10 : 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isOn ? accent : const Color(0xFFE2E8F0),
              width: isOn ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: cardStyle ? 14 : 13,
                        fontWeight: isOn ? FontWeight.w800 : FontWeight.w600,
                        color: isOn ? accent : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.extraPrice > 0 ? _price(t) : (l10n?.free ?? 'Free'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOn ? accent.withValues(alpha: 0.7) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _icon(isOn, single),
                size: 20,
                color: isOn ? accent : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
