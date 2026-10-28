import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ld.dart';
import 'manage_items_screen.dart';
import 'product_edit_screen.dart';
import '../utils/money.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;

  List<Product> _products = [];
  List<dynamic> _categories = [];
  List<Topping> _toppings = [];

  // Local search / category filter of the loaded list (display only).
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fresh from the server: the cache may hold an old or shorter list.
      final productsFuture = _apiService.fetchProducts(forceRefresh: true);
      final categoriesFuture = _apiService.fetchCategories();
      // Fresh: groups and defaults may have changed on the Toppings screen.
      final toppingsFuture = _apiService.fetchToppings(forceRefresh: true);

      final products = await productsFuture;
      final categories = await categoriesFuture;
      final toppingsRaw = await toppingsFuture;

      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _toppings = toppingsRaw
              .map((t) => Topping.fromJson(Map<String, dynamic>.from(t as Map)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _openProductScreen({Product? product}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditScreen(
          product: product,
          categories: _categories,
          toppings: _toppings,
        ),
      ),
    ).then((saved) {
      if (saved == true) _fetchData();
    });
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)?.deleteProduct ?? 'Delete Product'),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantTo3 ?? 'Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: itemsDangerButtonStyle(),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteProduct(id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.productDeleted ?? 'Product deleted'),
            backgroundColor: Ld.warning,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Ld.danger,
          ),
        );
      }
    }
  }

  List<Product> get _visibleProducts => _products
      .where((p) => p.matchesQuery(_query) && (_categoryFilter == null || p.category == _categoryFilter))
      .toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: LdHeader(
        title: l10n?.manageProducts ?? 'Manage Products',
        subtitle: !_isLoading && _errorMessage == null && _products.isNotEmpty
            ? (l10n?.itemsCount('${_products.length}') ?? '${_products.length}')
            : null,
        actions: [
          ItemsHeaderAction(
            label: l10n?.addProduct ?? 'Add Product',
            icon: Icons.add_rounded,
            onPressed: () => _openProductScreen(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? ItemsStateView(
                  icon: Icons.error_outline_rounded,
                  title: _errorMessage!,
                  isError: true,
                  actionLabel: l10n?.retry ?? 'Retry',
                  actionIcon: Icons.refresh_rounded,
                  onAction: _fetchData,
                )
              : _products.isEmpty
                  ? ItemsStateView(
                      icon: Icons.inventory_2_outlined,
                      title: l10n?.noProductsYet ?? 'No products yet',
                      message: l10n?.addYourFirstProductToGet ?? 'Add your first product to get started',
                      actionLabel: l10n?.addProduct ?? 'Add Product',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _openProductScreen(),
                    )
                  : _buildList(context),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: l10n?.addProduct ?? 'Add Product',
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openProductScreen(),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gutter = itemsGutter(context);
    final categories = <String>{for (final p in _products) p.category}.toList()..sort();
    final visible = _visibleProducts;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 10),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n?.searchProducts ?? 'Search products...',
              prefixIcon: const Icon(Icons.search_rounded, color: Ld.muted),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n?.clear ?? 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        if (categories.length > 1)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(gutter, 2, gutter, 8),
              children: [
                LdChoiceChip(
                  label: l10n?.historyAll ?? 'All',
                  count: '${_products.length}',
                  selected: _categoryFilter == null,
                  onTap: () => setState(() => _categoryFilter = null),
                ),
                for (final c in categories) ...[
                  const SizedBox(width: 8),
                  LdChoiceChip(
                    label: c,
                    selected: _categoryFilter == c,
                    onTap: () => setState(() => _categoryFilter = _categoryFilter == c ? null : c),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            child: visible.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Column(
                          children: [
                            const LdIconTile(Icons.search_off_rounded, size: 56, background: Ld.surface),
                            const SizedBox(height: 12),
                            Text(l10n?.noItemsFound ?? 'No items found', style: Ld.label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 96 + Ld.navInset(context)),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      return _ProductCard(
                        product: product,
                        wide: wide,
                        onTap: () => _openProductScreen(product: product),
                        onDelete: () => _deleteProduct(product.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// "PROMO" → "Promo" (the design uses sentence case; Lao is unchanged).
String _sentence(String s) {
  if (s.length < 2 || s != s.toUpperCase() || s == s.toLowerCase()) return s;
  return s[0] + s.substring(1).toLowerCase();
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool wide;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.wide,
    required this.onTap,
    required this.onDelete,
  });

  /// The name in the other language, shown small under the main one.
  String? get _otherName {
    final lao = product.nameLo?.trim() ?? '';
    if (lao.isEmpty || lao == product.name) return null;
    return product.displayName == product.name ? lao : product.name;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final other = _otherName;
    final openPrice = product.price == 0;

    final names = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Ld.ink, height: 1.3),
        ),
        if (other != null)
          Text(other, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
      ],
    );

    final price = Text(
      '₭${money(product.price)}',
      maxLines: 1,
      style: Ld.price(17, color: openPrice ? Ld.muted : Ld.navy, weight: FontWeight.w600),
    );

    final tags = <Widget>[
      if (openPrice)
        LdPill(l10n?.enterPrice ?? 'Enter price',
            icon: Icons.edit_note_rounded, background: Ld.infoWash, foreground: Ld.info),
      if (product.promotionPrice != null)
        LdPill('${_sentence(l10n?.promoBadge ?? 'Promo')} ₭${money(product.promotionPrice)}',
            icon: Icons.local_offer_outlined, background: Ld.dangerWash, foreground: Ld.danger),
      if (product.toppings.isNotEmpty)
        LdPill('${product.toppings.length} ${l10n?.toppings ?? 'Toppings'}', icon: Icons.tune_rounded),
      if (product.hideInSelfOrder)
        LdPill(l10n?.posOnlyLabel ?? 'POS only',
            icon: Icons.visibility_off_outlined, background: Ld.warningWash, foreground: Ld.warning),
      if (product.blockSelfOrder)
        LdPill(l10n?.blocked ?? 'Blocked',
            icon: Icons.block_rounded, background: Ld.dangerWash, foreground: Ld.danger),
    ];

    final delete = ItemsRowButton(
      icon: Icons.delete_outline_rounded,
      tooltip: l10n?.delete ?? 'Delete',
      danger: true,
      onPressed: onDelete,
    );

    final Widget content;
    if (wide) {
      // Tablet: one table-like row (item, category, price, tags, actions).
      content = Row(
        children: [
          _Thumb(product: product),
          const SizedBox(width: 14),
          Expanded(flex: 26, child: names),
          const SizedBox(width: 12),
          Expanded(
            flex: 12,
            child: Text(product.category,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Ld.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 12,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(fit: BoxFit.scaleDown, child: price),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 18, child: Wrap(spacing: 6, runSpacing: 6, children: tags)),
          const SizedBox(width: 12),
          const ItemsEditMark(),
          const SizedBox(width: 8),
          delete,
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(product: product),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                names,
                const SizedBox(height: 4),
                // Price first at full size; the category moves under it when
                // there is no room beside it.
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    price,
                    Text(product.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: tags),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          delete,
        ],
      );
    }

    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rMd),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rMd)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 12, vertical: 12),
          child: content,
        ),
      ),
    );
  }
}

/// Product photo, or its first letter on a soft tile.
class _Thumb extends StatelessWidget {
  final Product product;
  const _Thumb({required this.product});

  @override
  Widget build(BuildContext context) {
    final imageBytes = product.decodedImageBytes;
    final hasUrl = product.imageUrl != null && product.imageUrl!.isNotEmpty;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Ld.ground,
        borderRadius: BorderRadius.circular(Ld.r),
        border: Border.all(color: Ld.lineSoft),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes != null
          ? Image.memory(imageBytes, fit: BoxFit.cover)
          : hasUrl
              ? Image.network(product.imageUrl!, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    product.displayName.isNotEmpty ? product.displayName.substring(0, 1).toUpperCase() : '?',
                    style: Ld.title(21),
                  ),
                ),
    );
  }
}
