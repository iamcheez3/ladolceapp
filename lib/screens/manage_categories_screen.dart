import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import 'category_edit_screen.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _categories = [];

  static const Color _accent = Colors.blue;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.fetchCategories();
      if (mounted) {
        setState(() {
          _categories = data;
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

  void _openCategoryScreen({Map<String, dynamic>? category}) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryEditScreen(
          category: category,
          categories: _categories,
        ),
      ),
    ).then((saved) {
      if (saved == true) _fetchCategories();
    });
  }

  Future<void> _deleteCategory(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: const Text('Are you sure you want to delete this category?'),
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
      await _apiService.deleteCategory(id);
      _fetchCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Category deleted'), backgroundColor: Colors.orange),
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
        title: const Text('Manage Categories'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () => _openCategoryScreen(),
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
                            onPressed: _fetchCategories,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: LaDolcePosUi.primaryButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  )
                : _categories.isEmpty
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
                                child: Icon(Icons.category_outlined, color: _accent.withValues(alpha: 0.5), size: 40),
                              ),
                              const SizedBox(height: 20),
                              const Text('No categories yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('Add your first category to get started',
                                  style: TextStyle(fontSize: 14, color: LaDolcePosUi.mutedText)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Category'),
                                onPressed: () => _openCategoryScreen(),
                                style: LaDolcePosUi.primaryButtonStyle(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 88),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return _CategoryCard(
                            name: cat['name'] ?? '',
                            isVisible: cat['pos_show_in_app'] ?? true,
                            accent: _accent,
                            onTap: () => _openCategoryScreen(category: cat),
                            onDelete: () => _deleteCategory(cat['id']),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openCategoryScreen(),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final bool isVisible;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.name,
    required this.isVisible,
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
                  child: Icon(Icons.category, color: accent, size: 22),
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
                          Icon(
                            isVisible ? Icons.visibility : Icons.visibility_off,
                            size: 14,
                            color: isVisible ? Colors.green : LaDolcePosUi.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVisible ? 'Visible in app' : 'Hidden in app',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isVisible ? Colors.green : LaDolcePosUi.mutedText,
                            ),
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
