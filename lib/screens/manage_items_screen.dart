import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'manage_toppings_screen.dart';
import 'manage_categories_screen.dart';
import 'manage_products_screen.dart';
// import 'manage_combos_screen.dart'; // Combos card hidden, see below.
import '../theme/ld.dart';

class ManageItemsScreen extends StatelessWidget {
  const ManageItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cards = <Widget>[
      _buildMenuCard(
        context,
        icon: Icons.restaurant_menu_outlined,
        title: l10n?.products ?? 'Products',
        subtitle: l10n?.manageYourActiveProductCatalog ?? 'Manage your active product catalog',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageProductsScreen()));
        },
      ),
      _buildMenuCard(
        context,
        icon: Icons.grid_view_outlined,
        title: l10n?.categories ?? 'Categories',
        subtitle: l10n?.organizeProductsIntoGroups ?? 'Organize products into groups',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()));
        },
      ),
      // Hiding Combos feature per user request
      // _buildMenuCard(
      //   context,
      //   icon: Icons.auto_awesome_mosaic_outlined,
      //   title: l10n?.combos ?? 'Combos',
      //   subtitle: 'Create special combination deals',
      //   onTap: () {
      //     Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCombosScreen()));
      //   },
      // ),
      _buildMenuCard(
        context,
        icon: Icons.add_circle_outline,
        title: l10n?.toppings ?? 'Toppings',
        subtitle: l10n?.addOnsModifiersAndVariations ?? 'Add-ons, modifiers, and variations',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageToppingsScreen()));
        },
      ),
    ];

    return Scaffold(
      appBar: LdHeader(title: l10n?.manageCatalog ?? 'Manage Catalog'),
      body: LayoutBuilder(
        builder: (context, box) {
          final columns = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 600 ? 2 : 1);
          final pad = box.maxWidth >= 600 ? 24.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + Ld.navInset(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, inner) {
                    const gap = 14.0;
                    final w = (inner.maxWidth - gap * (columns - 1)) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [for (final c in cards) SizedBox(width: w, child: c)],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rLg),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                LdIconTile(icon, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Ld.title(19),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Ld.small,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Ld.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared look of the items-management screens ──────────────────────────
// (products, categories, toppings, topping groups, combos and their edit
// screens). Kept here because these screens are restyled together.

/// Main action on the navy header ("Add product", "Save"): gold on navy.
/// On narrow phones it collapses to a 48 px icon button with a tooltip.
class ItemsHeaderAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool primary;

  const ItemsHeaderAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    final bg = primary ? Ld.gold : Colors.transparent;
    final fg = primary ? Ld.navy : Colors.white;
    final side = primary ? BorderSide.none : const BorderSide(color: Ld.navyLine);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.r), side: side);
    final Widget glyph = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Icon(icon, size: 20, color: fg);
    if (compact) {
      return Tooltip(
        message: label,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: bg,
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: busy ? null : onPressed,
              child: Center(child: glyph),
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: SizedBox(
        height: 48,
        child: Material(
          color: bg,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: busy ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph,
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error / empty states shared by the item lists.
class ItemsStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool isError;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  const ItemsStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.isError = false,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + Ld.navInset(context)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LdIconTile(
                icon,
                size: 72,
                background: isError ? Ld.dangerWash : Ld.surface,
                color: isError ? Ld.danger : Ld.navy,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Ld.title(20, color: isError ? Ld.danger : Ld.navy),
              ),
              if (message != null && message!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(message!, textAlign: TextAlign.center, style: Ld.label),
              ],
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 20),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 44 px outlined icon button for list rows (delete in red, edit in navy).
class ItemsRowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  const ItemsRowButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Ld.r),
      side: BorderSide(color: danger ? Ld.dangerLine : Ld.line),
    );
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Ld.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: Icon(icon, size: 20, color: danger ? Ld.danger : Ld.navy),
          ),
        ),
      ),
    );
  }
}

/// The pencil "edit" mark at the end of a tappable row. Decorative: the
/// whole row opens the editor, so it is not a separate button.
class ItemsEditMark extends StatelessWidget {
  const ItemsEditMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Ld.r),
          border: Border.all(color: Ld.line),
        ),
        child: const Icon(Icons.edit_outlined, size: 19, color: Ld.navy),
      ),
    );
  }
}

/// Confirmation dialogs: the destructive button in danger red.
ButtonStyle itemsDangerButtonStyle() => ElevatedButton.styleFrom(
      backgroundColor: Ld.danger,
      foregroundColor: Colors.white,
      elevation: 0,
    );

/// Side padding of the item screens (wider on tablets).
double itemsGutter(BuildContext context) => MediaQuery.sizeOf(context).width >= 600 ? 24 : 16;

/// A form card section with an optional small heading.
class ItemsFormCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final List<Widget> children;

  const ItemsFormCard({super.key, this.title, this.icon, this.trailing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: Ld.navy),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Ld.ink),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Small grey caption under a field ("0 = enter the price at the POS").
class ItemsFieldHint extends StatelessWidget {
  final String text;
  const ItemsFieldHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Text(text, style: Ld.small),
    );
  }
}

/// "₭" prefix for money fields, in the receipt font.
const Widget itemsKipPrefix = Padding(
  padding: EdgeInsets.only(left: 14, right: 6),
  // Centered: the prefix box is 48 px tall and a bare Text would sit at its top.
  child: Center(
    widthFactor: 1,
    child: Text('₭', style: TextStyle(fontFamily: Ld.serif, fontSize: 19, fontWeight: FontWeight.w700, color: Ld.muted)),
  ),
);

/// Text style of typed money, in the receipt font.
const TextStyle itemsMoneyInputStyle =
    TextStyle(fontFamily: Ld.serif, fontSize: 19, fontWeight: FontWeight.w700, color: Ld.ink);

/// A setting row with a switch (icon, title, help, switch); the whole row
/// toggles.
class ItemsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ItemsSwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(Ld.r),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              LdIconTile(icon, size: 40, background: value ? Ld.ground : Ld.surface, color: value ? Ld.navy : Ld.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Ld.ink)),
                    Text(subtitle, style: Ld.small),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
