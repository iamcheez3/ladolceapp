import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../utils/l10n_ext.dart';
import '../widgets/topping_picker.dart';

/// How the customer self-order app treats a product.
enum _SelfOrderMode { available, runOut, posOnly }

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
  late _SelfOrderMode _selfOrderMode;
  late List<int> _selectedToppingIds;
  bool _isSaving = false;

  static const Color _productAccent = Color(0xFF0891B2);

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    _selfOrderMode = (product?.hideInSelfOrder ?? false)
        ? _SelfOrderMode.posOnly
        : (product?.blockSelfOrder ?? false)
        ? _SelfOrderMode.runOut
        : _SelfOrderMode.available;

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
    final price = double.tryParse(priceStr) ?? 0.0;

    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.validNameAndPriceAreRequired)),
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
        blockSelfOrder: _selfOrderMode == _SelfOrderMode.runOut,
        hideInSelfOrder: _selfOrderMode == _SelfOrderMode.posOnly,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.productSavedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.errorWithMessage(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? widget.product!.name : context.l10n.addProduct,
        ),
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
              child: Text(
                context.l10n.save,
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSection(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: LaDolcePosUi.input(
                      hintText: context.l10n.productName,
                      prefixIcon: const Icon(Icons.label_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _priceController,
                    decoration: LaDolcePosUi.input(
                      hintText: context.l10n.listPrice,
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    decoration: LaDolcePosUi.input(
                      hintText: context.l10n.category,
                    ),
                    value: _selectedCategoryId,
                    items: widget.categories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? ''),
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
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                        color: LaDolcePosUi.mutedText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.customerSelfOrder,
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
                    title: context.l10n.tableAvailable,
                    subtitle: context.l10n.customersCanSelectAndOrder,
                    isSelected: _selfOrderMode == _SelfOrderMode.available,
                    onTap: () => setState(
                      () => _selfOrderMode = _SelfOrderMode.available,
                    ),
                  ),
                  const Divider(height: 1, indent: 44),
                  _buildSelfOrderTile(
                    icon: Icons.remove_circle_outline,
                    iconColor: Colors.orange,
                    title: context.l10n.runOutBlocked,
                    subtitle: context.l10n.shownAsRunOutCannotAdd,
                    isSelected: _selfOrderMode == _SelfOrderMode.runOut,
                    onTap: () =>
                        setState(() => _selfOrderMode = _SelfOrderMode.runOut),
                  ),
                  const Divider(height: 1, indent: 44),
                  _buildSelfOrderTile(
                    icon: Icons.visibility_off_outlined,
                    iconColor: Colors.deepPurple,
                    title: context.l10n.posOnly,
                    subtitle: context.l10n.posOnlyHint,
                    isSelected: _selfOrderMode == _SelfOrderMode.posOnly,
                    onTap: () =>
                        setState(() => _selfOrderMode = _SelfOrderMode.posOnly),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.extension_outlined,
                        size: 18,
                        color: LaDolcePosUi.mutedText,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.availableToppings,
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
                      child: Text(
                        context.l10n.noToppingsConfigured,
                        style: TextStyle(
                          color: LaDolcePosUi.mutedText,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    for (final section in ToppingRules.sections(
                      widget.toppings,
                    ))
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
                label: Text(_isSaving ? 'Saving...' : context.l10n.saveProduct),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Milk · Pick 1 · Required   All", then the group's options as chips.
  Widget _buildToppingSection(ToppingSection section) {
    final ids = section.options.map((t) => t.id).toList();
    final allSelected = ids.every(_selectedToppingIds.contains);
    final parts = section.isGroup
        ? [
            section.title,
            section.multiple ? context.l10n.pickMany : context.l10n.pickOne,
            if (section.required) context.l10n.requiredLabel,
          ]
        : [context.l10n.noGroupAddOn];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  parts.join(' · '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: LaDolcePosUi.mutedText,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedToppingIds.removeWhere(ids.contains);
                  if (!allSelected) _selectedToppingIds.addAll(ids);
                }),
                child: Text(context.l10n.selectAllShort),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final t in section.options) _buildToppingChip(t)],
          ),
        ],
      ),
    );
  }

  Widget _buildToppingChip(Topping t) {
    final isSelected = _selectedToppingIds.contains(t.id);
    final price = t.extraPrice > 0
        ? ' +₭${t.extraPrice.toStringAsFixed(0)}'
        : '';
    return FilterChip(
      label: Text(
        '${t.displayName}$price',
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: isSelected ? _productAccent : LaDolcePosUi.mutedText,
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
