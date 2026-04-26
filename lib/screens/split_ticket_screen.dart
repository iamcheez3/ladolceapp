import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/topping.dart';

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
  bool movedToNew = false;

  _SplitLine({required this.product, required this.selectedToppings});

  double get unitPrice {
    double base = product.price;
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

  static const _green = Color(0xFF4CAF50);
  static const _darkGreen = Color(0xFF388E3C);

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
          '${line.product.id}__${line.selectedToppings.map((t) => t.id).join(',')}';
      if (merged.containsKey(key)) {
        merged[key]!.quantity++;
      } else {
        merged[key] = CartItem(
          product: line.product,
          quantity: 1,
          isSaved: false,
          selectedToppings: line.selectedToppings,
        );
      }
    }
    return merged.values.toList();
  }

  void _save() {
    if (_newLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please move at least one item to the new ticket.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_originalLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The original ticket cannot be empty. Keep at least one item.'),
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
        title: const Text('Rename New Ticket'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ticket Name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Split Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ─── Left: Original Ticket ───────────────────────────────────────
          Expanded(
            child: _TicketColumn(
              title: widget.ticketName,
              lines: _originalLines,
              total: _originalTotal,
              isNew: false,
              onLineTap: (line) {
                setState(() => line.movedToNew = true);
              },
              moveButtonLabel: 'MOVE →',
              accentColor: const Color(0xFF1E3A8A),
            ),
          ),
          // Divider
          Container(width: 1, color: Colors.grey[300]),
          // ─── Right: New Ticket ──────────────────────────────────────────
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
              moveButtonLabel: '← MOVE BACK',
              accentColor: _darkGreen,
            ),
          ),
        ],
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
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isNew)
                GestureDetector(
                  onTap: onTitleTap,
                  child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                ),
              if (!isNew)
                Icon(Icons.add_circle_outline, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),

        // Items list
        Expanded(
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    isNew ? 'Tap items on the\nleft to move them here' : 'All items moved',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: lines.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, i) {
                    final line = lines[i];
                    return InkWell(
                      onTap: () => onLineTap(line),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Indicator icon
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: accentColor.withValues(alpha: 0.12),
                              child: Icon(
                                isNew
                                    ? Icons.arrow_back_ios_new
                                    : Icons.arrow_forward_ios,
                                size: 12,
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
                                    line.product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14),
                                  ),
                                  if (line.selectedToppings.isNotEmpty)
                                    Text(
                                      line.selectedToppings
                                          .map((t) => t.name)
                                          .join(', '),
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            // Price
                            Text(
                              '₭${line.unitPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Total row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '₭${total.toStringAsFixed(2)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: accentColor),
              ),
            ],
          ),
        ),

        // Move button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(),
              elevation: 0,
            ),
            onPressed: lines.isEmpty ? null : () {
              // move all visible items at once
              for (final l in List.from(lines)) {
                onLineTap(l);
              }
            },
            child: Text(
              moveButtonLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }
}
