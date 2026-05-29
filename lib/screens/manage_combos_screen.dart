import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import 'combo_edit_screen.dart';

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

  static const Color _accent = Color(0xFF7C3AED);

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
          _combos = futures[0];
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

  void _openComboScreen({Map<String, dynamic>? combo}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ComboEditScreen(
          combo: combo,
          allProducts: _allProducts,
        ),
      ),
    ).then((saved) {
      if (saved == true) _fetchData();
    });
  }

  Future<void> _deleteCombo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Combo'),
        content: const Text('Are you sure you want to delete this combo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: LaDolcePosUi.primaryButtonStyle(isDestructive: true),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _apiService.deleteCombo(id);
      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Combo deleted'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
        title: const Text('Manage Combos'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Combo',
            onPressed: () => _openComboScreen(),
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
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 32),
                          ),
                          const SizedBox(height: 16),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _fetchData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: LaDolcePosUi.primaryButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  )
                : _combos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: _accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(Icons.dashboard_customize_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
                              ),
                              const SizedBox(height: 20),
                              const Text('No combos yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('Add your first combo to get started',
                                  style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Combo'),
                                onPressed: () => _openComboScreen(),
                                style: LaDolcePosUi.primaryButtonStyle(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: _combos.length,
                        itemBuilder: (context, index) {
                          final combo = _combos[index];
                          final itemsCount = (combo['lines'] as List).length;
                          return _ComboCard(
                            name: combo['name'] ?? '',
                            price: (combo['price'] ?? 0.0).toDouble(),
                            itemsCount: itemsCount,
                            accent: _accent,
                            onTap: () => _openComboScreen(combo: combo),
                            onDelete: () => _deleteCombo(combo['id']),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openComboScreen(),
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final String name;
  final double price;
  final int itemsCount;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ComboCard({
    required this.name,
    required this.price,
    required this.itemsCount,
    required this.accent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '\$${price.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: accent),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$itemsCount item${itemsCount == 1 ? '' : 's'}',
                            style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 36, height: 36,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.red.withValues(alpha: 0.7),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    tooltip: 'Delete',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
