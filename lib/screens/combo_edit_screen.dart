import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../theme/ld.dart';
import '../utils/money.dart';
import 'manage_items_screen.dart';

class ComboEditScreen extends StatefulWidget {
  final Map<String, dynamic>? combo;
  final List<Product> allProducts;

  const ComboEditScreen({
    super.key,
    this.combo,
    required this.allProducts,
  });

  bool get isEditing => combo != null;

  @override
  State<ComboEditScreen> createState() => _ComboEditScreenState();
}

class _ComboEditScreenState extends State<ComboEditScreen> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late List<_ComboLine> _lines;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.combo?['name'] ?? '');
    _priceController = TextEditingController(
      text: widget.combo != null ? money(num.tryParse('${widget.combo!['price']}')) : '',
    );

    _lines = [];
    if (widget.combo != null && widget.combo!['lines'] != null) {
      for (var line in widget.combo!['lines']) {
        _lines.add(_ComboLine(
          productId: line['product_id'],
          product: widget.allProducts.firstWhere(
            (p) => p.id == line['product_id'],
            orElse: () => widget.allProducts.first,
          ),
          qty: line['qty'],
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addLine() {
    if (widget.allProducts.isEmpty) return;
    setState(() {
      _lines.add(_ComboLine(
        productId: widget.allProducts.first.id,
        product: widget.allProducts.first,
        qty: 1,
      ));
    });
  }

  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final price = parseMoney(priceStr);

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? 'Valid name and price are required')),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.comboMustHaveAtLeastOne ?? 'Combo must have at least one product')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final apiLines = _lines
          .map((l) => {'product_id': l.productId, 'qty': l.qty})
          .toList();

      await _apiService.saveCombo(
        name: name,
        price: price,
        lines: apiLines,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.comboSavedSuccessfully ?? 'Combo saved successfully'),
            backgroundColor: Ld.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Ld.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gutter = itemsGutter(context);
    return Scaffold(
      appBar: LdHeader(
        title: widget.isEditing ? widget.combo!['name'] : (l10n?.addCombo ?? 'Add Combo'),
        actions: [
          ItemsHeaderAction(
            label: l10n?.save ?? 'Save',
            icon: Icons.check_rounded,
            busy: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40 + Ld.navInset(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ItemsFormCard(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 17, color: Ld.ink),
                      decoration: InputDecoration(
                        labelText: l10n?.comboName ?? 'Combo Name*',
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      style: itemsMoneyInputStyle,
                      decoration: InputDecoration(
                        labelText: l10n?.comboFixedPrice ?? 'Combo Fixed Price*',
                        prefixIcon: itemsKipPrefix,
                        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ItemsFormCard(
                  title: l10n?.comboItems ?? 'Combo Items',
                  icon: Icons.widgets_outlined,
                  trailing: TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(l10n?.addProduct ?? 'Add Product'),
                  ),
                  children: [
                    if (_lines.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Ld.ground,
                          borderRadius: BorderRadius.circular(Ld.rMd),
                        ),
                        child: Text(
                          l10n?.noProductsAddedToThisCombo ?? 'No products added to this combo yet.',
                          textAlign: TextAlign.center,
                          style: Ld.label,
                        ),
                      )
                    else
                      ..._lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ComboLineCard(
                            line: line,
                            allProducts: widget.allProducts,
                            onProductChanged: (productId) {
                              setState(() {
                                line.productId = productId;
                                line.product = widget.allProducts.firstWhere((p) => p.id == productId);
                              });
                            },
                            onQtyChanged: (qty) {
                              setState(() => line.qty = qty);
                            },
                            onRemove: () => _removeLine(i),
                          ),
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(_isSaving ? 'Saving...' : (l10n?.saveCombo ?? 'Save Combo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComboLine {
  int productId;
  Product product;
  int qty;

  _ComboLine({
    required this.productId,
    required this.product,
    this.qty = 1,
  });
}

class _ComboLineCard extends StatelessWidget {
  final _ComboLine line;
  final List<Product> allProducts;
  final ValueChanged<int> onProductChanged;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _ComboLineCard({
    required this.line,
    required this.allProducts,
    required this.onProductChanged,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Ld.ground,
        borderRadius: BorderRadius.circular(Ld.rMd),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: line.productId,
              decoration: InputDecoration(labelText: l10n?.product ?? 'Product'),
              isExpanded: true,
              items: allProducts.map((p) {
                return DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(p.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onProductChanged(val);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: TextFormField(
              initialValue: line.qty.toString(),
              decoration: InputDecoration(labelText: l10n?.qty ?? 'Qty'),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (val) {
                final qty = int.tryParse(val) ?? 1;
                if (qty > 0) onQtyChanged(qty);
              },
            ),
          ),
          const SizedBox(width: 8),
          ItemsRowButton(
            icon: Icons.remove_circle_outline,
            tooltip: l10n?.delete ?? 'Delete',
            danger: true,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
