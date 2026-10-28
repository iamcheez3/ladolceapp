import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ld.dart';
import '../widgets/topping_picker.dart';
import '../utils/money.dart';
import 'manage_items_screen.dart';

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
        SnackBar(content: Text(AppLocalizations.of(context)?.validNameAndPriceAreRequired ?? 'Valid name and price are required')),
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
            content: Text(AppLocalizations.of(context)?.productSavedSuccessfully ?? 'Product saved successfully'),
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
    return Scaffold(
      appBar: LdHeader(
        title: widget.isEditing ? widget.product!.name : (l10n?.addProduct ?? 'Add Product'),
        actions: [
          ItemsHeaderAction(
            label: l10n?.save ?? 'Save',
            icon: Icons.check_rounded,
            busy: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 840;
          final gutter = box.maxWidth >= 600 ? 24.0 : 16.0;
          final form = <Widget>[
            _buildMainFields(wide),
            const SizedBox(height: 16),
            _buildToppingsCard(wide),
            const SizedBox(height: 16),
            _buildSelfOrderCard(),
          ];
          final saveButton = ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(_isSaving ? 'Saving...' : (l10n?.saveProduct ?? 'Save Product')),
          );
          return SingleChildScrollView(
            // Keep the Save button above the navigation bar.
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40 + Ld.navInset(context)),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 13,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [...form, const SizedBox(height: 24), saveButton],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(flex: 7, child: _buildPreview()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...form,
                          const SizedBox(height: 16),
                          _buildPreview(),
                          const SizedBox(height: 24),
                          saveButton,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainFields(bool wide) {
    final l10n = AppLocalizations.of(context);
    final name = TextField(
      controller: _nameController,
      style: const TextStyle(fontSize: 17, color: Ld.ink),
      decoration: InputDecoration(
        labelText: l10n?.productName ?? 'Product Name*',
        prefixIcon: const Icon(Icons.label_outline, size: 20),
      ),
    );
    final price = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _priceController,
          style: itemsMoneyInputStyle,
          decoration: InputDecoration(
            labelText: l10n?.listPrice ?? 'List Price*',
            prefixIcon: itemsKipPrefix,
            prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
        ),
        ItemsFieldHint(l10n?.openPriceHint ?? '0 = enter the price at the POS'),
      ],
    );
    final category = DropdownButtonFormField<int>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n?.category ?? 'Category',
        prefixIcon: const Icon(Icons.grid_view_outlined, size: 20),
      ),
      // ignore: deprecated_member_use
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
    );

    return ItemsFormCard(
      children: wide
          ? [
              name,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: category),
                  const SizedBox(width: 16),
                  Expanded(child: price),
                ],
              ),
            ]
          : [
              name,
              const SizedBox(height: 16),
              price,
              const SizedBox(height: 16),
              category,
            ],
    );
  }

  Widget _buildToppingsCard(bool wide) {
    final l10n = AppLocalizations.of(context);
    return ItemsFormCard(
      title: l10n?.availableToppings ?? 'Available Toppings',
      icon: Icons.extension_outlined,
      children: [
        if (widget.toppings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n?.noToppingsConfigured ?? 'No toppings configured.', style: Ld.label),
          )
        else
          for (final section in ToppingRules.sections(widget.toppings)) _buildToppingSection(section, wide),
      ],
    );
  }

  Widget _buildSelfOrderCard() {
    final l10n = AppLocalizations.of(context);
    return ItemsFormCard(
      title: l10n?.customerSelfOrder ?? 'Customer self-order',
      icon: Icons.shopping_cart_outlined,
      children: [
        _buildSelfOrderTile(
          icon: Icons.check_circle_outline,
          iconColor: Ld.success,
          iconBackground: Ld.successWash,
          title: l10n?.tableAvailable ?? 'Available',
          subtitle: l10n?.customersCanSelectAndOrder ?? 'Customers can select and order',
          isSelected: !_blockSelfOrder && !_hideInSelfOrder,
          onTap: () => setState(() {
            _blockSelfOrder = false;
            _hideInSelfOrder = false;
          }),
        ),
        const Divider(height: 1, indent: 56),
        _buildSelfOrderTile(
          icon: Icons.remove_circle_outline,
          iconColor: Ld.warning,
          iconBackground: Ld.warningWash,
          title: l10n?.runOutBlocked ?? 'Run out (blocked)',
          subtitle: l10n?.shownAsRunOutCannotAdd ?? 'Shown as run out; cannot add to cart',
          isSelected: _blockSelfOrder && !_hideInSelfOrder,
          onTap: () => setState(() {
            _blockSelfOrder = true;
            _hideInSelfOrder = false;
          }),
        ),
        const Divider(height: 1, indent: 56),
        // POS only: not listed in the customer app at all.
        _buildSelfOrderTile(
          icon: Icons.visibility_off_outlined,
          iconColor: Ld.info,
          iconBackground: Ld.infoWash,
          title: l10n?.posOnlyLabel ?? 'POS only',
          subtitle: l10n?.posOnlyProductHelp ?? 'Hidden in self-order; only the cashier can sell it',
          isSelected: _hideInSelfOrder,
          onTap: () => setState(() {
            _hideInSelfOrder = true;
            _blockSelfOrder = false;
          }),
        ),
      ],
    );
  }

  /// How the product tile will look on the sales screen, updated as the
  /// name and price are typed.
  Widget _buildPreview() {
    final l10n = AppLocalizations.of(context);
    final product = widget.product;
    final imageBytes = product?.decodedImageBytes;
    final imageUrl = product?.imageUrl;
    final hasImage = imageBytes != null || (imageUrl != null && imageUrl.isNotEmpty);
    final lao = product?.nameLo?.trim() ?? '';

    return Container(
      decoration: Ld.card(radius: Ld.rXl),
      padding: const EdgeInsets.all(18),
      child: AnimatedBuilder(
        animation: Listenable.merge([_nameController, _priceController]),
        builder: (context, _) {
          final typed = _nameController.text.trim();
          final laoFirst = Product.useLaoNames && lao.isNotEmpty;
          final primary = laoFirst ? lao : typed;
          final secondary = laoFirst ? typed : (lao.isNotEmpty && lao != typed ? lao : '');
          final price = parseMoney(_priceController.text.trim());
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(Ld.rMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: imageBytes != null
                        ? Image.memory(imageBytes, fit: BoxFit.cover)
                        : Image.network(imageUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Container(
                constraints: const BoxConstraints(minHeight: 132),
                padding: const EdgeInsets.all(16),
                decoration: Ld.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary.isEmpty ? (l10n?.productName ?? 'Product Name*') : primary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: primary.isEmpty ? Ld.faint : Ld.ink,
                        height: 1.3,
                      ),
                    ),
                    if (secondary.isNotEmpty)
                      Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '₭${money(price)}',
                          style: Ld.price(19, color: price == 0 ? Ld.muted : Ld.navy, weight: FontWeight.w600),
                        ),
                        if (price == 0)
                          LdPill(l10n?.enterPrice ?? 'Enter price',
                              icon: Icons.edit_note_rounded, background: Ld.infoWash, foreground: Ld.info),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One topping group (or the plain add-ons) as a heading + chips. "All"
  /// ticks every option of the group, e.g. Hot, Iced and Frappe at once.
  Widget _buildToppingSection(ToppingSection section, bool wide) {
    final l10n = AppLocalizations.of(context);
    final ids = section.options.map((t) => t.id).toList();
    final allOn = ids.every(_selectedToppingIds.contains);
    final title = section.groupId == null
        ? (l10n?.toppingNoGroup ?? 'No group (add-on)')
        : '${section.title} · ${section.single ? (l10n?.toppingPickOne ?? 'Pick 1') : (l10n?.toppingPickMany ?? 'Pick many')}'
            '${section.required ? ' · ${l10n?.toppingRequired ?? 'Required'}' : ''}';
    final allButton = TextButton(
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
    );
    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: section.options.map((t) {
        final isSelected = _selectedToppingIds.contains(t.id);
        return FilterChip(
          label: Text(
            t.extraPrice > 0 ? '${t.displayName} +₭${money(t.extraPrice)}' : t.displayName,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
              color: isSelected ? Ld.navy : Ld.muted,
            ),
          ),
          selected: isSelected,
          backgroundColor: Ld.surface,
          selectedColor: Ld.ground,
          checkmarkColor: Ld.navy,
          side: BorderSide(color: isSelected ? Ld.navy : Ld.line),
          shape: const StadiumBorder(),
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
    );
    final heading = Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Ld.ink),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ld.lineSoft))),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.only(top: 8), child: heading),
                      allButton,
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: chips)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: heading),
                    allButton,
                  ],
                ),
                chips,
              ],
            ),
    );
  }

  Widget _buildSelfOrderTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ld.r),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 24,
                color: isSelected ? Ld.navy : Ld.muted,
              ),
              const SizedBox(width: 12),
              LdIconTile(icon, size: 36, background: iconBackground, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 15,
                        color: isSelected ? Ld.ink : Ld.muted,
                      ),
                    ),
                    Text(subtitle, style: Ld.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
