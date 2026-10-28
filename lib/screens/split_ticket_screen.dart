import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ld.dart';
import '../utils/money.dart';

/// Result returned when the user saves the split.
class SplitTicketResult {
  final List<CartItem> remainingItems; // Items still on original ticket
  final List<CartItem> newItems;       // Items moved to new ticket
  final String newTicketName;

  SplitTicketResult({
    required this.remainingItems,
    required this.newItems,
    required this.newTicketName,
  });
}

/// A single "unrolled" line (qty=1 each) used internally in this screen.
class _SplitLine {
  final Product product;
  final List<Topping> selectedToppings;
  final String kitchenNote;
  bool movedToNew = false;

  _SplitLine({
    required this.product,
    required this.selectedToppings,
    this.kitchenNote = '',
  });

  double get unitPrice {
    double base = product.effectivePrice;
    for (final t in selectedToppings) {
      base += t.extraPrice;
    }
    return base;
  }
}

class SplitTicketScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final String ticketName;

  const SplitTicketScreen({
    super.key,
    required this.cartItems,
    required this.ticketName,
  });

  @override
  State<SplitTicketScreen> createState() => _SplitTicketScreenState();
}

class _SplitTicketScreenState extends State<SplitTicketScreen> {
  late List<_SplitLine> _lines;
  late String _newTicketName;


  @override
  void initState() {
    super.initState();
    // Unroll cart items: Beer x 3 → three _SplitLine entries
    _lines = [];
    for (final item in widget.cartItems) {
      for (int i = 0; i < item.quantity; i++) {
        _lines.add(_SplitLine(
          product: item.product,
          selectedToppings: List.from(item.selectedToppings),
          kitchenNote: item.kitchenNote,
        ));
      }
    }
    // Generate default split name: "T 1 - 1" or increment suffix
    _newTicketName = _generateSplitName(widget.ticketName);
  }

  /// Produces "Ticket - 1" → "Ticket - 1 -1", or "T3 -1" → "T3 -1 -1"
  String _generateSplitName(String original) {
    // Regex to detect already-split tickets: "name - N"
    final re = RegExp(r'^(.*)\s+-\s+(\d+)$');
    final match = re.firstMatch(original.trim());
    if (match != null) {
      final base = match.group(1)!;
      final n = int.parse(match.group(2)!);
      return '$base - ${n + 1}';
    }
    return '$original - 1';
  }

  List<_SplitLine> get _originalLines =>
      _lines.where((l) => !l.movedToNew).toList();

  List<_SplitLine> get _newLines =>
      _lines.where((l) => l.movedToNew).toList();

  double get _originalTotal =>
      _originalLines.fold(0.0, (sum, l) => sum + l.unitPrice);

  double get _newTotal =>
      _newLines.fold(0.0, (sum, l) => sum + l.unitPrice);

  /// Roll up _SplitLine list back into CartItem list (merge same product+toppings)
  List<CartItem> _rollUp(List<_SplitLine> lines) {
    final Map<String, CartItem> merged = {};
    for (final line in lines) {
      final key =
          '${line.product.id}__${line.selectedToppings.map((t) => t.id).join(',')}__${line.kitchenNote}';
      if (merged.containsKey(key)) {
        merged[key]!.quantity++;
      } else {
        merged[key] = CartItem(
          product: line.product,
          quantity: 1,
          isSaved: false,
          selectedToppings: line.selectedToppings,
          kitchenNote: line.kitchenNote,
        );
      }
    }
    return merged.values.toList();
  }

  void _save() {
    if (_newLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.pleaseMoveAtLeastOneItem ?? (AppLocalizations.of(context)?.pleaseMoveAtLeastOneItem ?? 'Please move at least one item to the new ticket.')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_originalLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)?.theOriginalTicketCannotBeEmpty ?? (AppLocalizations.of(context)?.theOriginalTicketCannotBeEmpty ?? 'The original ticket cannot be empty. Keep at least one item.')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      SplitTicketResult(
        remainingItems: _rollUp(_originalLines),
        newItems: _rollUp(_newLines),
        newTicketName: _newTicketName,
      ),
    );
  }

  void _editNewTicketName() {
    final ctrl = TextEditingController(text: _newTicketName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.renameNewTicket ?? 'Rename New Ticket'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: AppLocalizations.of(context)?.ticketName ?? 'Ticket Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          FilledButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() => _newTicketName = name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Ld.ground,
      appBar: LdHeader(
        title: l10n?.splitTicket ?? 'Split Ticket',
        subtitle: widget.ticketName,
        actions: [
          FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: Ld.gold,
              foregroundColor: Ld.navy,
              minimumSize: const Size(64, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(l10n?.save ?? 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Left: Original Ticket ─────────────────────────────────────
              Expanded(
                child: _TicketColumn(
                  title: widget.ticketName,
                  lines: _originalLines,
                  total: _originalTotal,
                  isNew: false,
                  onLineTap: (line) {
                    setState(() => line.movedToNew = true);
                  },
                  moveButtonLabel: 'Move →',
                  accentColor: Ld.navy,
                ),
              ),
              const SizedBox(width: 8),
              // ─── Right: New Ticket ────────────────────────────────────────
              Expanded(
                child: _TicketColumn(
                  title: _newTicketName,
                  lines: _newLines,
                  total: _newTotal,
                  isNew: true,
                  onTitleTap: _editNewTicketName,
                  onLineTap: (line) {
                    setState(() => line.movedToNew = false);
                  },
                  moveButtonLabel: '← Move back',
                  accentColor: Ld.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable column widget for each half of the split screen
// ─────────────────────────────────────────────────────────────────────────────
class _TicketColumn extends StatelessWidget {
  final String title;
  final List<_SplitLine> lines;
  final double total;
  final bool isNew;
  final VoidCallback? onTitleTap;
  final void Function(_SplitLine line) onLineTap;
  final String moveButtonLabel;
  final Color accentColor;

  const _TicketColumn({
    required this.title,
    required this.lines,
    required this.total,
    required this.isNew,
    required this.onLineTap,
    required this.moveButtonLabel,
    required this.accentColor,
    this.onTitleTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: Ld.card(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header (the new ticket's name can be edited).
          InkWell(
            onTap: isNew ? onTitleTap : null,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Ld.lineSoft)),
              ),
              child: Row(
                children: [
                  Icon(
                    isNew ? Icons.call_split_rounded : Icons.receipt_long_outlined,
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Ld.title(16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isNew)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(Icons.edit_outlined, size: 18, color: Ld.muted),
                    ),
                ],
              ),
            ),
          ),

          // Items list
          Expanded(
            child: lines.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        isNew
                            ? (l10n?.tapItemsOnTheLeftTo ?? 'Tap items on the\nleft to move them here')
                            : (l10n?.allItemsMoved ?? 'All items moved'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Ld.muted, fontSize: 14),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (context, i) {
                      final line = lines[i];
                      return InkWell(
                        onTap: () => onLineTap(line),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Row(
                              children: [
                                // Which way a tap moves the line.
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Ld.ground,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isNew ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Name + toppings
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 14.5, color: Ld.ink),
                                      ),
                                      if (line.selectedToppings.isNotEmpty)
                                        Text(
                                          line.selectedToppings.map((t) => t.displayName).join(', '),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Ld.muted, fontSize: 12.5),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Price
                                Text(
                                  '₭${money(line.unitPrice)}',
                                  style: Ld.price(14, color: Ld.ink, weight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Total row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Ld.ground,
              border: Border(top: BorderSide(color: Ld.lineSoft)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n?.total ?? 'Total',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Ld.muted),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text('₭${money(total)}', style: Ld.price(18)),
                  ),
                ),
              ],
            ),
          ),

          // Move every line at once.
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: lines.isEmpty ? Ld.lineSoft : accentColor),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: lines.isEmpty
                    ? null
                    : () {
                        // move all visible items at once
                        for (final l in List.from(lines)) {
                          onLineTap(l);
                        }
                      },
                child: Text(
                  moveButtonLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
