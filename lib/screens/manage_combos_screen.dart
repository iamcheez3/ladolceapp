import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

class ManageCombosScreen extends StatefulWidget {
  const ManageCombosScreen({super.key});

  @override
  State<ManageCombosScreen> createState() => _ManageCombosScreenState();
}

class _ManageCombosScreenState extends State<ManageCombosScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  
  List<dynamic> _combos = [];
  List<Product> _allProducts = [];

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
      final futures = await Future.wait([
        _apiService.fetchCombos(),
        _apiService.fetchProducts(),
      ]);
      
      if (mounted) {
        setState(() {
          _combos = futures[0] as List<dynamic>;
          _allProducts = futures[1] as List<Product>;
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

  void _showComboForm({Map<String, dynamic>? combo}) {
    final nameController = TextEditingController(text: combo?['name'] ?? '');
    final priceController = TextEditingController(text: combo != null ? combo['price'].toString() : '');
    
    // Maintain a list of lines for the combo (product_id, qty)
    List<Map<String, dynamic>> lines = [];
    if (combo != null && combo['lines'] != null) {
      for (var line in combo['lines']) {
        lines.add({
          'product_id': line['product_id'],
          // For display, fetch product object
          'product': _allProducts.firstWhere((p) => p.id == line['product_id'], orElse: () => _allProducts.first),
          'qty': line['qty'],
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      combo == null ? 'Add New Combo Set' : 'Edit Combo Set',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Combo Name*'),
                      autofocus: combo == null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'Combo Fixed Price*', prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Combo Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                          onPressed: () {
                            if (_allProducts.isEmpty) return;
                            setSheetState(() {
                              lines.add({
                                'product_id': _allProducts.first.id,
                                'product': _allProducts.first,
                                'qty': 1,
                              });
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    if (lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No products added to this combo yet.', style: TextStyle(color: Colors.grey)),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          final line = lines[index];
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  value: line['product_id'],
                                  items: _allProducts.map((p) {
                                    return DropdownMenuItem<int>(
                                      value: p.id,
                                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSheetState(() {
                                        line['product_id'] = val;
                                        line['product'] = _allProducts.firstWhere((p) => p.id == val);
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  initialValue: line['qty'].toString(),
                                  decoration: const InputDecoration(labelText: 'Qty'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    line['qty'] = int.tryParse(val) ?? 1;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () {
                                  setSheetState(() {
                                    lines.removeAt(index);
                                  });
                                },
                              )
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final priceStr = priceController.text.trim();
                            final price = double.tryParse(priceStr) ?? 0.0;

                            if (name.isEmpty || price <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid Name and Price are required')));
                              return;
                            }
                            if (lines.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Combo must have at least one product')));
                              return;
                            }

                            Navigator.pop(context);
                            
                            // Map lines to pure API format
                            final apiLines = lines.map((l) => {
                              'product_id': l['product_id'],
                              'qty': l['qty'],
                            }).toList();

                            _saveCombo(
                              name: name,
                              price: price,
                              lines: apiLines,
                            );
                          },
                          child: const Text('Save Combo'),
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

  Future<void> _saveCombo({required String name, required double price, required List<Map<String, dynamic>> lines}) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.saveCombo(
        name: name,
        price: price,
        lines: lines,
      );
      _fetchData(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Combo saved successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteCombo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Combo'),
        content: const Text('Are you sure you want to delete this Combo?'),
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
      await _apiService.deleteCombo(id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Combo deleted'), backgroundColor: Colors.orange));
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
        title: const Text('Manage Combos'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Combo',
            onPressed: () => _showComboForm(),
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
              : _combos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No Combos found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Combo Set'),
                            onPressed: () => _showComboForm(),
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _combos.length,
                      itemBuilder: (context, index) {
                        final combo = _combos[index];
                        final itemsCount = (combo['lines'] as List).length;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            onTap: () => _showComboForm(combo: combo), // Edit is not fully supported by API yet (only POST creates), but UI supports the form.
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.purple[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Center(
                                child: Text(
                                  combo['name'].toString().isNotEmpty ? combo['name'].toString().substring(0, 1).toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                ),
                              ),
                            ),
                            title: Text(combo['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('\$${combo['price'].toStringAsFixed(2)}  |  $itemsCount items included'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteCombo(combo['id']),
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
        onPressed: () => _showComboForm(),
      ),
    );
  }
}
