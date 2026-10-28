import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/cart_item.dart';
import '../models/pos_discount_config.dart';
import '../models/pos_tax_config.dart';
import '../theme/ld.dart';
import '../utils/pos_discount.dart';
import '../utils/money.dart';

/// "SAVE TICKET" -> "Save ticket": some English labels are stored in capitals;
/// the design uses sentence case. Lao (no case) is returned unchanged.
String _sentence(String s) {
  if (s != s.toUpperCase() || !RegExp(r'[A-Z]').hasMatch(s)) return s;
  final lower = s.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

/// The current ticket as a white paper strip on a navy rail: ticket name,
/// customer, the lines (saved ones locked, new ones with - / +), the promo
/// banner, the torn edge, a big gold total and Save ticket / Charge.
class CartSidebar extends StatelessWidget {
  final List<CartItem> cartItems;
  final Function(CartItem, int) onUpdateQuantity;
  final VoidCallback onClearCart;
  final VoidCallback onCharge;
  final VoidCallback onSaveTicket;
  final VoidCallback onViewTickets;
  final ValueChanged<CartItem> onEditKitchenNote;

  final VoidCallback onAddCustomer;
  final VoidCallback onClearCustomer;
  final Map<String, dynamic>? selectedCustomer;
  final PosTaxConfig taxConfig;
  final PosDiscountOption? selectedDiscountOption;
  final double? discountManualValue;

  /// "Buy 2 get 1 free" banner (free items available / too many), shown
  /// above the totals. Built by the POS screen, which knows the promotions.
  final Widget? promoBanner;

  /// Name of the open ticket (table or custom name); null for a new cart.
  final String? ticketName;

  /// Small line under the ticket name (e.g. the order number).
  final String? ticketSubtitle;

  /// Extra header button (the ticket options menu on the tablet rail).
  final Widget? optionsButton;

  const CartSidebar({
    super.key,
    required this.cartItems,
    required this.onUpdateQuantity,
    required this.onClearCart,
    required this.onCharge,
    required this.onSaveTicket,
    required this.onViewTickets,
    required this.onEditKitchenNote,
    required this.onAddCustomer,
    required this.onClearCustomer,
    this.selectedCustomer,
    this.taxConfig = PosTaxConfig.disabled,
    this.selectedDiscountOption,
    this.discountManualValue,
    this.promoBanner,
    this.ticketName,
    this.ticketSubtitle,
    this.optionsButton,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linesSum = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final cd = computeCartBreakdown(
      linesSum,
      taxConfig,
      selectedDiscountOption: selectedDiscountOption,
      discountManualValue: discountManualValue,
    );

    return ColoredBox(
      color: Ld.navy,
      child: LayoutBuilder(builder: (context, box) {
        // Short sheets (small phones, large text) get tighter spacing so the
        // paper keeps room for the lines.
        final compact = box.maxHeight < 560;
        final side = box.maxWidth < 340 ? 12.0 : 16.0;
        final gap = compact ? 10.0 : 14.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(side, compact ? 12 : 16, side, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, l10n),
              SizedBox(height: gap - 4),
              _customerButton(context, l10n),
              SizedBox(height: gap),

              // ── The paper ───────────────────────────────────────────────
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Ld.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(Ld.rMd)),
                  ),
                  child: Column(
                    children: [
                      _paperHeader(context, l10n),
                      Expanded(child: _lines(context, l10n)),
                      if (promoBanner != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: promoBanner!,
                        ),
                    ],
                  ),
                ),
              ),
              const LdTicketEdge(),
              SizedBox(height: gap - 2),

              // ── Totals on navy ──────────────────────────────────────────
              ..._totals(context, l10n, cd, compact),
              SizedBox(height: gap),

              // ── Save ticket / Charge ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: compact ? 52 : 60,
                      child: OutlinedButton(
                        onPressed: cartItems.isEmpty ? null : onSaveTicket,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Ld.onNavyMuted,
                          side: const BorderSide(color: Ld.navyLine),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
                        ),
                        child: Text(
                          _sentence(l10n?.saveTicket ?? 'Save ticket'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: compact ? 52 : 60,
                      child: FilledButton(
                        onPressed: cartItems.isEmpty ? null : onCharge,
                        style: FilledButton.styleFrom(
                          backgroundColor: Ld.gold,
                          foregroundColor: Ld.navy,
                          disabledBackgroundColor: Ld.navyRaised,
                          disabledForegroundColor: Ld.onNavyMuted,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
                        ),
                        child: Text(
                          _sentence(l10n?.charge2 ?? 'Charge'),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: (compact ? 10 : 16) + Ld.navInset(context)),
            ],
          ),
        );
      }),
    );
  }

  /// Ticket name on navy, plus the options menu when the screen gives one.
  Widget _header(BuildContext context, AppLocalizations? l10n) {
    final named = (ticketName ?? '').trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (named)
                Text(
                  l10n?.currentTicket2 ?? 'Current ticket',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Ld.onNavyMuted),
                ),
              Text(
                named ? ticketName!.trim() : (l10n?.currentTicket2 ?? 'Current ticket'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ld.title(named ? 22 : 20, color: Colors.white),
              ),
              if ((ticketSubtitle ?? '').trim().isNotEmpty)
                Text(
                  ticketSubtitle!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Ld.onNavyMuted),
                ),
            ],
          ),
        ),
        if (optionsButton != null) ...[const SizedBox(width: 8), optionsButton!],
      ],
    );
  }

  /// "Add customer", or the chosen customer (with points) and a clear button.
  Widget _customerButton(BuildContext context, AppLocalizations? l10n) {
    final c = selectedCustomer;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.r),
        side: const BorderSide(color: Ld.navyLine),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ld.r),
        onTap: c == null ? onAddCustomer : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(left: 14, right: c == null ? 14 : 2),
            child: Row(
              children: [
                Icon(
                  c != null ? Icons.person_rounded : Icons.person_add_alt_1_outlined,
                  color: c != null ? Ld.gold : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: c != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${c['name']}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // A customer restored from a saved ticket has no
                            // points loaded; skip the line rather than "null pts".
                            if (c['reward_points'] != null)
                              Text(
                                '${c['reward_points']} pts',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: Ld.onNavyMuted),
                              ),
                          ],
                        )
                      : Text(
                          l10n?.addCustomer ?? 'Add customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                ),
                if (c != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                    onPressed: onClearCustomer,
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Item count and the clear-ticket button at the top of the paper.
  Widget _paperHeader(BuildContext context, AppLocalizations? l10n) {
    final count = cartItems.fold<int>(0, (s, i) => s + i.quantity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n?.itemsCount('$count') ?? '$count items',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Ld.muted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            color: Ld.danger,
            disabledColor: Ld.faint,
            onPressed: cartItems.isEmpty ? null : onClearCart,
            tooltip: l10n?.clearTicket2 ?? 'Clear Ticket',
          ),
        ],
      ),
    );
  }

  /// Cart lines, split into already ordered (saved) and new ones.
  Widget _lines(BuildContext context, AppLocalizations? l10n) {
    if (cartItems.isEmpty) {
      return LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 44, color: Ld.faint),
                    const SizedBox(height: 10),
                    Text(
                      l10n?.noItemsInTicket ?? 'No items in ticket',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Ld.muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final savedItems = cartItems.where((i) => i.isSaved).toList();
    final newItems = cartItems.where((i) => !i.isSaved).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        // ── Already ordered ──────────────────────────────────────────────
        if (savedItems.isNotEmpty) ...[
          _sectionLabel(
            Icons.check_circle_outline_rounded,
            _sentence(l10n?.alreadyOrdered ?? 'Already ordered'),
            Ld.success,
          ),
          ...savedItems.map((item) => _CartItemRow(
                item: item,
                isSaved: true,
                onUpdateQuantity: onUpdateQuantity,
                onEditKitchenNote: onEditKitchenNote,
              )),
        ],

        // ── New items ────────────────────────────────────────────────────
        if (newItems.isNotEmpty) ...[
          if (savedItems.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _DashedLine(),
            ),
          _sectionLabel(
            Icons.add_circle_outline_rounded,
            _sentence(l10n?.newItems ?? 'New items'),
            Ld.warning,
          ),
          ...newItems.map((item) => _CartItemRow(
                item: item,
                isSaved: false,
                onUpdateQuantity: onUpdateQuantity,
                onEditKitchenNote: onEditKitchenNote,
              )),
        ],
      ],
    );
  }

  Widget _sectionLabel(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// Subtotal / VAT rows and the big gold total, on navy.
  List<Widget> _totals(BuildContext context, AppLocalizations? l10n, CartBreakdown cd, bool compact) {
    Widget row(String label, double value) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Ld.onNavyMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text('₭${money(value)}', style: Ld.price(15, color: Colors.white, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );

    final totalLabel = cd.taxActive ? (l10n?.totalDue ?? 'Total due') : (l10n?.total ?? 'Total');
    final caption = !cd.taxActive
        ? null
        : taxConfig.showOnReceipt
            ? (taxConfig.inclusive
                ? (l10n?.priceIncludesTax ?? 'Price includes tax')
                : (l10n?.includesVat ?? 'Includes VAT'))
            : (l10n?.taxHiddenOnReceipt ?? 'Tax hidden on receipt');

    return [
      row(l10n?.subtotal ?? 'Subtotal', cd.cartLinesSum),
      if (cd.taxActive) ...[
        row(
          taxConfig.inclusive
              ? (l10n?.amountExclVat2 ?? 'Amount (excl. VAT)')
              : (l10n?.subtotalExclVat ?? 'Subtotal (excl. VAT)'),
          cd.baseAmount,
        ),
        if (taxConfig.showOnReceipt) row('VAT (${taxConfig.percentLabel}%)', cd.taxAmount),
      ],
      const SizedBox(height: 2),
      LayoutBuilder(
        builder: (context, box) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: Ld.onNavyMuted, height: 1.3),
                  ),
                  if (caption != null)
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Ld.onNavyMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box.maxWidth * 0.7),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '₭${money(cd.totalDue)}',
                  style: Ld.price(compact || box.maxWidth < 320 ? 30 : 38, color: Ld.gold),
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// Dashed divider between the saved and the new lines.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final n = (box.maxWidth / 8).floor();
      return Row(
        children: List.generate(
          n,
          (_) => Expanded(
            child: Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 2), color: Ld.line),
          ),
        ),
      );
    });
  }
}

// ─── Reusable cart row widget ────────────────────────────────────────────────
class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final bool isSaved;
  final Function(CartItem, int) onUpdateQuantity;
  final ValueChanged<CartItem> onEditKitchenNote;

  const _CartItemRow({
    required this.item,
    required this.isSaved,
    required this.onUpdateQuantity,
    required this.onEditKitchenNote,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final free = l10n?.freeItemLabel ?? 'FREE';
    final unit = item.priceUnitFromOrder != null
        ? item.priceUnitFromOrder! - item.selectedToppings.fold<double>(0, (s, t) => s + t.extraPrice)
        : item.product.effectivePrice;
    final toppings = item.selectedToppings.map((t) {
      return t.extraPrice > 0 && !item.isFreePromo
          ? '${t.displayName} +₭${money(t.extraPrice)}'
          : t.displayName;
    }).join(', ');

    return InkWell(
      onTap: () => onEditKitchenNote(item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: LayoutBuilder(builder: (context, box) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity: locked for saved lines.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity}×',
                      style: Ld.price(17, color: isSaved ? Ld.muted : Ld.navy),
                    ),
                    if (isSaved)
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.lock_outline_rounded, size: 14, color: Ld.faint),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.5,
                        height: 1.3,
                        color: isSaved ? Ld.muted : Ld.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.isFreePromo)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: LdPill(
                          item.promotionName.isNotEmpty
                              ? '${_sentence(free)} · ${item.promotionName}'
                              : _sentence(free),
                          icon: Icons.card_giftcard_rounded,
                          background: Ld.successWash,
                          foreground: Ld.success,
                        ),
                      ),
                    if (!item.isFreePromo)
                      Text(
                        '₭${money(unit)} each',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Ld.muted, fontSize: 12.5),
                      ),
                    if (toppings.isNotEmpty)
                      Text(
                        toppings,
                        style: const TextStyle(fontSize: 13, color: Ld.muted, height: 1.35),
                      ),
                    if (item.kitchenNote.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.sticky_note_2_outlined, size: 14, color: Ld.warning),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.kitchenNote.trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Ld.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // - / + for new lines only.
                    if (!isSaved)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepButton(
                              icon: Icons.remove_rounded,
                              onPressed: () => onUpdateQuantity(item, item.quantity - 1),
                            ),
                            const SizedBox(width: 8),
                            _StepButton(
                              icon: Icons.add_rounded,
                              // A free item cannot grow past what the promotion
                              // allows; the cashier adds another through the
                              // promotion banner.
                              onPressed: item.isFreePromo
                                  ? null
                                  : () => onUpdateQuantity(item, item.quantity + 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.36),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topRight,
                  child: Text(
                    item.isFreePromo ? _sentence(free) : '₭${money(item.totalPrice)}',
                    style: item.isFreePromo
                        ? const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Ld.success)
                        : Ld.price(16, color: isSaved ? Ld.muted : Ld.ink, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// 44 px outlined - / + button for a cart line.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 40),
          foregroundColor: Ld.navy,
          side: const BorderSide(color: Ld.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rSm)),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}
