import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

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

  static const Color _accent = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.combo?['name'] ?? '');
    _priceController = TextEditingController(
      text: widget.combo != null ? widget.combo!['price'].toString() : '',
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
    final price = double.tryParse(priceStr) ?? 0.0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? (AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? 'Valid name and price are required'))),
      );
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.comboMustHaveAtLeastOne ?? (AppLocalizations.of(context)?.comboMustHaveAtLeastOne ?? 'Combo must have at least one product'))),
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
            content: Text(AppLocalizations.of(context)?.comboSavedSuccessfully ?? (AppLocalizations.of(context)?.comboSavedSuccessfully ?? 'Combo saved successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? widget.combo!['name'] : (AppLocalizations.of(context)?.addCombo ?? 'Add Combo')),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(AppLocalizations.of(context)?.save ?? (AppLocalizations.of(context)?.save ?? 'Save'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LaDolcePosUi.card,
                  borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                  border: Border.all(color: LaDolcePosUi.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.comboName ?? (AppLocalizations.of(context)?.comboName ?? 'Combo Name*'),
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _priceController,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.comboFixedPrice ?? (AppLocalizations.of(context)?.comboFixedPrice ?? 'Combo Fixed Price*'),
                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.widgets_outlined, size: 18, color: LaDolcePosUi.mutedText),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)?.comboItems ?? (AppLocalizations.of(context)?.comboItems ?? 'Combo Items'),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)?.addProduct ?? (AppLocalizations.of(context)?.addProduct ?? 'Add Product'), style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: _accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_lines.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: LaDolcePosUi.card,
                    borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                    border: Border.all(color: LaDolcePosUi.border.withValues(alpha: 0.6)),
                  ),
                  child: Text(AppLocalizations.of(context)?.noProductsAddedToThisCombo ?? (AppLocalizations.of(context)?.noProductsAddedToThisCombo ?? 'No products added to this combo yet.'),
                    style: TextStyle(color: LaDolcePosUi.mutedText, fontSize: 13),
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
                      accent: _accent,
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
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isSaving ? 'Saving...' : (AppLocalizations.of(context)?.saveCombo ?? 'Save Combo')),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
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
  final Color accent;
  final ValueChanged<int> onProductChanged;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _ComboLineCard({
    required this.line,
    required this.allProducts,
    required this.accent,
    required this.onProductChanged,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LaDolcePosUi.card,
        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
        border: Border.all(color: LaDolcePosUi.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int>(
              value: line.productId,
              decoration: LaDolcePosUi.input(hintText: AppLocalizations.of(context)?.product ?? (AppLocalizations.of(context)?.product ?? 'Product')),
              isExpanded: true,
              items: allProducts.map((p) {
                return DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(p.displayName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onProductChanged(val);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: TextFormField(
              initialValue: line.qty.toString(),
              decoration: LaDolcePosUi.input(hintText: AppLocalizations.of(context)?.qty ?? (AppLocalizations.of(context)?.qty ?? 'Qty')),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (val) {
                final qty = int.tryParse(val) ?? 1;
                if (qty > 0) onQtyChanged(qty);
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 22),
            color: Colors.red.withValues(alpha: 0.7),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
