import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../services/api_service.dart';
import '../models/product.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

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

  void _showProductForm({Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    
    // Find matching category ID if editing, or default to first category if creating
    int? selectedCategoryId;
    if (product != null) {
      final cat = _categories.firstWhere((c) => c['name'] == product.category, orElse: () => null);
      if (cat != null) selectedCategoryId = cat['id'];
    } else if (_categories.isNotEmpty) {
      selectedCategoryId = _categories.first['id'];
    }

    // Set up toppings state
    List<int> selectedToppingIds = product?.toppings.map((t) => t.id).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: LaDolcePosUi.modalBottomPadding(context),
                left: 24, right: 24, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      product == null ? 'Add New Product' : 'Edit Product',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Product Name*'),
                      autofocus: product == null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'List Price*', prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Category'),
                      initialValue: selectedCategoryId,
                      items: _categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c['id'],
                          child: Text(c['name']),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setSheetState(() => selectedCategoryId = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text('Available Toppings', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_toppings.isEmpty)
                      const Text('No toppings configured.', style: TextStyle(color: Colors.grey))
                    else
                      Wrap(
                        spacing: 8,
                        children: _toppings.map((t) {
                          final isSelected = selectedToppingIds.contains(t.id);
                          return FilterChip(
                            label: Text(t.name),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              setSheetState(() {
                                if (selected) {
                                  selectedToppingIds.add(t.id);
                                } else {
                                  selectedToppingIds.remove(t.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final priceStr = priceController.text.trim();
                            final price = double.tryParse(priceStr) ?? 0.0;

                            if (name.isEmpty || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid Name and Price are required')));
                              return;
                            }

                            Navigator.pop(context);
                            _saveProduct(
                              id: product?.id,
                              name: name,
                              price: price,
                              categoryId: selectedCategoryId,
                              toppingIds: selectedToppingIds,
                            );
                          },
                          child: const Text('Save Product'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveProduct({int? id, required String name, required double price, int? categoryId, required List<int> toppingIds}) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.saveProduct(
        id: id,
        name: name,
        listPrice: price,
        categoryId: categoryId,
        toppingIds: toppingIds,
      );
      _fetchData(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteProduct(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete'),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteProduct(id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Product',
            onPressed: () => _showProductForm(),
          )
        ],
      ),
      body: LuxuryPatternBackground(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchData, child: const Text('Retry'))
                    ],
                  ),
                )
              : _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No products found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            onPressed: () => _showProductForm(),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        Uint8List? imageBytes;
                        if (product.imageBase64 != null && product.imageBase64!.isNotEmpty) {
                          try {
                            imageBytes = base64Decode(product.imageBase64!);
                          } catch (_) {
                            imageBytes = null;
                          }
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            onTap: () => _showProductForm(product: product),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Color(product.colorCode),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: imageBytes != null
                                ? Image.memory(imageBytes, fit: BoxFit.cover)
                                : (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                                    ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                : Center(
                                    child: Text(
                                      product.name.isNotEmpty ? product.name.substring(0, 1).toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                  ),
                            ),
                            title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${product.category}  |  \$${product.price.toStringAsFixed(2)}\n${product.toppings.length} Toppings enabled'),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteProduct(product.id),
                            ),
                          ),
                        );
                      },
                    ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _showProductForm(),
      ),
    );
  }
}
