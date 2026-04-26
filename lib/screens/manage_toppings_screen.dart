import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

class ManageToppingsScreen extends StatefulWidget {
  const ManageToppingsScreen({super.key});

  @override
  State<ManageToppingsScreen> createState() => _ManageToppingsScreenState();
}

class _ManageToppingsScreenState extends State<ManageToppingsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Topping> _toppings = [];

  @override
  void initState() {
    super.initState();
    _fetchToppings();
  }

  Future<void> _fetchToppings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchToppings();
      if (mounted) {
        setState(() {
          _toppings = data.map((json) => Topping.fromJson(json)).toList();
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

  void _showAddDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Topping'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Topping Name*'),
                autofocus: true,
              ),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Extra Price (Optional)', prefixText: '\$'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceStr = priceController.text.trim();
                final price = double.tryParse(priceStr) ?? 0.0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                  return;
                }

                Navigator.pop(context);
                _addTopping(name, price);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addTopping(String name, double price) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.addTopping(name, price);
      _fetchToppings(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Topping added successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteTopping(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Topping'),
        content: const Text('Are you sure you want to delete this topping?'),
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
      await _apiService.deleteTopping(id);
      _fetchToppings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Topping deleted'), backgroundColor: Colors.orange));
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
        title: const Text('Manage Toppings'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Topping',
            onPressed: _showAddDialog,
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
                      ElevatedButton(onPressed: _fetchToppings, child: const Text('Retry'))
                    ],
                  ),
                )
              : _toppings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('No toppings found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Topping'),
                            onPressed: _showAddDialog,
                          )
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _toppings.length,
                      itemBuilder: (context, index) {
                        final topping = _toppings[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              child: const Icon(Icons.add_circle_outline, color: Colors.green),
                            ),
                            title: Text(topping.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(topping.extraPrice > 0 ? '+\$${topping.extraPrice.toStringAsFixed(2)}' : 'Free'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteTopping(topping.id),
                            ),
                          ),
                        );
                      },
                    ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
