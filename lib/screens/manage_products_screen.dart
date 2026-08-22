import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import 'product_edit_screen.dart';

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

  static const Color _productAccent = Color(0xFF0891B2);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productsFuture = _apiService.fetchProducts();
      final categoriesFuture = _apiService.fetchCategories();
      final toppingsFuture = _apiService.fetchToppings();

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
        title: Text(AppLocalizations.of(context)?.deleteProduct ?? (AppLocalizations.of(context)?.deleteProduct ?? 'Delete Product')),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantTo3 ?? (AppLocalizations.of(context)?.areYouSureYouWantTo3 ?? 'Are you sure you want to delete this product?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? (AppLocalizations.of(context)?.cancel ?? 'Cancel')),
          ),
          ElevatedButton(
            style: LaDolcePosUi.primaryButtonStyle(isDestructive: true),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)?.delete ?? (AppLocalizations.of(context)?.delete ?? 'Delete')),
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
            content: Text(AppLocalizations.of(context)?.productDeleted ?? (AppLocalizations.of(context)?.productDeleted ?? 'Product deleted')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
        title: Text(AppLocalizations.of(context)?.manageProducts ?? (AppLocalizations.of(context)?.manageProducts ?? 'Manage Products')),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context)?.addProduct ?? (AppLocalizations.of(context)?.addProduct ?? 'Add Product'),
            onPressed: () => _openProductScreen(),
          ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(AppLocalizations.of(context)?.retry ?? (AppLocalizations.of(context)?.retry ?? 'Retry')),
                            style: LaDolcePosUi.primaryButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  )
                : _products.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _productAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: _productAccent.withValues(alpha: 0.5),
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(AppLocalizations.of(context)?.noProductsYet ?? (AppLocalizations.of(context)?.noProductsYet ?? 'No products yet'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(AppLocalizations.of(context)?.addYourFirstProductToGet ?? (AppLocalizations.of(context)?.addYourFirstProductToGet ?? 'Add your first product to get started'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: LaDolcePosUi.mutedText,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(AppLocalizations.of(context)?.addProduct ?? (AppLocalizations.of(context)?.addProduct ?? 'Add Product')),
                                onPressed: () => _openProductScreen(),
                                style: LaDolcePosUi.primaryButtonStyle(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          top: 8,
                          bottom: 88,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return _ProductCard(
                            product: product,
                            accentColor: _productAccent,
                            onTap: () =>
                                _openProductScreen(product: product),
                            onDelete: () => _deleteProduct(product.id),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openProductScreen(),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.accentColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageBytes = product.decodedImageBytes;
    final hasImage = imageBytes != null ||
        (product.imageUrl != null && product.imageUrl!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
        child: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Leading image / initial
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: hasImage
                        ? Colors.transparent
                        : Color(product.colorCode),
                    borderRadius: BorderRadius.circular(12),
                    border: hasImage
                        ? Border.all(color: LaDolcePosUi.border)
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.cover)
                      : product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                product.name.isNotEmpty
                                    ? product.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                ),
                const SizedBox(width: 14),
                // Title + details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTag(
                            text: product.category,
                            color: accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      if (product.toppings.isNotEmpty ||
                          product.blockSelfOrder) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (product.toppings.isNotEmpty)
                              Text(
                                '${product.toppings.length} topping${product.toppings.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: LaDolcePosUi.mutedText,
                                ),
                              ),
                            if (product.toppings.isNotEmpty &&
                                product.blockSelfOrder)
                              const SizedBox(width: 8),
                            if (product.blockSelfOrder)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(AppLocalizations.of(context)?.blocked ?? (AppLocalizations.of(context)?.blocked ?? 'Blocked'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Delete
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.red.withValues(alpha: 0.7),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    tooltip: AppLocalizations.of(context)?.delete ?? (AppLocalizations.of(context)?.delete ?? 'Delete'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
