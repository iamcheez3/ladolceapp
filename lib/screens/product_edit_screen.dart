import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../widgets/topping_picker.dart';
import '../utils/money.dart';

class ProductEditScreen extends StatefulWidget {
  final Product? product;
  final List<dynamic> categories;
  final List<Topping> toppings;

  const ProductEditScreen({
    super.key,
    this.product,
    required this.categories,
    required this.toppings,
  });

  bool get isEditing => product != null;

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late int? _selectedCategoryId;
  late bool _blockSelfOrder;
  late bool _hideInSelfOrder;
  late List<int> _selectedToppingIds;
  bool _isSaving = false;

  static const Color _productAccent = Color(0xFF0891B2);

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(text: product != null ? money(product.price) : '');
    _blockSelfOrder = product?.blockSelfOrder ?? false;
    _hideInSelfOrder = product?.hideInSelfOrder ?? false;

    if (product != null) {
      final cat = widget.categories.firstWhere(
        (c) => c['name'] == product.category,
        orElse: () => null,
      );
      _selectedCategoryId = cat?['id'];
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first['id'];
    }

    _selectedToppingIds = product?.toppings.map((t) => t.id).toList() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final price = parseMoney(priceStr);

    // Price 0 = no fixed price: the cashier types it on the POS.
    if (name.isEmpty || price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? (AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? 'Valid name and price are required'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _apiService.saveProduct(
        id: widget.product?.id,
        name: name,
        listPrice: price,
        categoryId: _selectedCategoryId,
        toppingIds: _selectedToppingIds,
        blockSelfOrder: _blockSelfOrder,
        hideInSelfOrder: _hideInSelfOrder,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.productSavedSuccessfully ?? (AppLocalizations.of(context)?.productSavedSuccessfully ?? 'Product saved successfully')),
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
        title: Text(widget.isEditing ? widget.product!.name : (AppLocalizations.of(context)?.addProduct ?? 'Add Product')),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(AppLocalizations.of(context)?.save ?? (AppLocalizations.of(context)?.save ?? 'Save'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: SingleChildScrollView(
          // Keep the Save button above the navigation bar.
          padding: EdgeInsets.fromLTRB(20, 20, 20, 40 + MediaQuery.viewPaddingOf(context).bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: LaDolcePosUi.input(
                      hintText: AppLocalizations.of(context)?.productName ?? (AppLocalizations.of(context)?.productName ?? 'Product Name*'),
                      prefixIcon: const Icon(Icons.label_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceController,
                    decoration: LaDolcePosUi.input(
                      hintText: AppLocalizations.of(context)?.listPrice ?? (AppLocalizations.of(context)?.listPrice ?? 'List Price*'),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('₭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      AppLocalizations.of(context)?.openPriceHint ??
                          '0 = enter the price at the POS',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: LaDolcePosUi.input(hintText: AppLocalizations.of(context)?.category ?? (AppLocalizations.of(context)?.category ?? 'Category')),
                    value: _selectedCategoryId,
                    items: widget.categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(
                          c['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedCategoryId = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 18, color: LaDolcePosUi.mutedText),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)?.customerSelfOrder ?? (AppLocalizations.of(context)?.customerSelfOrder ?? 'Customer self-order'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSelfOrderTile(
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    title: AppLocalizations.of(context)?.tableAvailable ?? (AppLocalizations.of(context)?.tableAvailable ?? 'Available'),
                    subtitle: AppLocalizations.of(context)?.customersCanSelectAndOrder ?? (AppLocalizations.of(context)?.customersCanSelectAndOrder ?? 'Customers can select and order'),
                    isSelected: !_blockSelfOrder && !_hideInSelfOrder,
                    onTap: () => setState(() {
                      _blockSelfOrder = false;
                      _hideInSelfOrder = false;
                    }),
                  ),
                  const Divider(height: 1, indent: 44),
                  _buildSelfOrderTile(
                    icon: Icons.remove_circle_outline,
                    iconColor: Colors.orange,
                    title: AppLocalizations.of(context)?.runOutBlocked ?? (AppLocalizations.of(context)?.runOutBlocked ?? 'Run out (blocked)'),
                    subtitle: AppLocalizations.of(context)?.shownAsRunOutCannotAdd ?? (AppLocalizations.of(context)?.shownAsRunOutCannotAdd ?? 'Shown as run out; cannot add to cart'),
                    isSelected: _blockSelfOrder && !_hideInSelfOrder,
                    onTap: () => setState(() {
                      _blockSelfOrder = true;
                      _hideInSelfOrder = false;
                    }),
                  ),
                  const Divider(height: 1, indent: 44),
                  // POS only: not listed in the customer app at all.
                  _buildSelfOrderTile(
                    icon: Icons.visibility_off_outlined,
                    iconColor: Colors.deepPurple,
                    title: AppLocalizations.of(context)?.posOnlyLabel ?? 'POS only',
                    subtitle: AppLocalizations.of(context)?.posOnlyProductHelp ??
                        'Hidden in self-order; only the cashier can sell it',
                    isSelected: _hideInSelfOrder,
                    onTap: () => setState(() {
                      _hideInSelfOrder = true;
                      _blockSelfOrder = false;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                children: [
                  Row(
                    children: [
                      Icon(Icons.extension_outlined,
                          size: 18, color: LaDolcePosUi.mutedText),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)?.availableToppings ?? (AppLocalizations.of(context)?.availableToppings ?? 'Available Toppings'),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.toppings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(AppLocalizations.of(context)?.noToppingsConfigured ?? (AppLocalizations.of(context)?.noToppingsConfigured ?? 'No toppings configured.'),
                        style: TextStyle(
                          color: LaDolcePosUi.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (final section in ToppingRules.sections(widget.toppings))
                      _buildToppingSection(section),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isSaving ? 'Saving...' : (AppLocalizations.of(context)?.saveProduct ?? 'Save Product')),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One topping group (or the plain add-ons) as a heading + chips. "All"
  /// ticks every option of the group, e.g. Hot, Iced and Frappe at once.
  Widget _buildToppingSection(ToppingSection section) {
    final l10n = AppLocalizations.of(context);
    final ids = section.options.map((t) => t.id).toList();
    final allOn = ids.every(_selectedToppingIds.contains);
    final title = section.groupId == null
        ? (l10n?.toppingNoGroup ?? 'No group (add-on)')
        : '${section.title} · ${section.single ? (l10n?.toppingPickOne ?? 'Pick 1') : (l10n?.toppingPickMany ?? 'Pick many')}'
            '${section.required ? ' · ${l10n?.toppingRequired ?? 'Required'}' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: LaDolcePosUi.mutedText),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  if (allOn) {
                    _selectedToppingIds.removeWhere(ids.contains);
                  } else {
                    for (final id in ids) {
                      if (!_selectedToppingIds.contains(id)) _selectedToppingIds.add(id);
                    }
                  }
                }),
                child: Text(
                  allOn ? (l10n?.clear ?? 'Clear') : (l10n?.toppingSelectAll ?? 'All'),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: section.options.map((t) {
              final isSelected = _selectedToppingIds.contains(t.id);
              return FilterChip(
                label: Text(
                  t.extraPrice > 0 ? '${t.name} +₭${money(t.extraPrice)}' : t.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                    color: isSelected ? _productAccent : LaDolcePosUi.text,
                  ),
                ),
                selected: isSelected,
                selectedColor: _productAccent.withValues(alpha: 0.12),
                checkmarkColor: _productAccent,
                side: BorderSide(
                  color: isSelected
                      ? _productAccent.withValues(alpha: 0.4)
                      : LaDolcePosUi.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedToppingIds.add(t.id);
                    } else {
                      _selectedToppingIds.remove(t.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
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
        children: children,
      ),
    );
  }

  Widget _buildSelfOrderTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 22,
              color:
                  isSelected ? _productAccent : LaDolcePosUi.mutedText,
            ),
            const SizedBox(width: 12),
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSelected
                          ? LaDolcePosUi.text
                          : LaDolcePosUi.mutedText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: LaDolcePosUi.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
