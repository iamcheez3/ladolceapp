import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import 'category_edit_screen.dart';
import 'manage_items_screen.dart';

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
        title: Text(AppLocalizations.of(context)?.deleteCategory ?? 'Delete Category'),
        content: Text(AppLocalizations.of(context)?.areYouSureYouWantTo ?? 'Are you sure you want to delete this category?'),
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
      await _apiService.deleteCategory(id);
      _fetchCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.categoryDeleted ?? 'Category deleted'), backgroundColor: Ld.warning),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
    final gutter = itemsGutter(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      appBar: LdHeader(
        title: l10n?.manageCategories ?? 'Manage Categories',
        subtitle: !_isLoading && _errorMessage == null && _categories.isNotEmpty
            ? (l10n?.itemsCount('${_categories.length}') ?? '${_categories.length}')
            : null,
        actions: [
          ItemsHeaderAction(
            label: l10n?.addCategory ?? 'Add Category',
            icon: Icons.add_rounded,
            onPressed: () => _openCategoryScreen(),
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
                  onAction: _fetchCategories,
                )
              : _categories.isEmpty
                  ? ItemsStateView(
                      icon: Icons.category_outlined,
                      title: l10n?.noCategoriesYet ?? 'No categories yet',
                      message: l10n?.addYourFirstCategoryToGet ?? 'Add your first category to get started',
                      actionLabel: l10n?.addCategory ?? 'Add Category',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _openCategoryScreen(),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchCategories,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 96 + Ld.navInset(context)),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: _CategoryCard(
                                name: cat['name'] ?? '',
                                isVisible: cat['pos_show_in_app'] ?? true,
                                posOnly: cat['hide_in_self_order'] == true,
                                wide: wide,
                                onTap: () => _openCategoryScreen(category: cat),
                                onDelete: () => _deleteCategory(cat['id']),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: l10n?.addCategory ?? 'Add Category',
        child: const Icon(Icons.add_rounded),
        onPressed: () => _openCategoryScreen(),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final bool isVisible;
  final bool posOnly;
  final bool wide;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.name,
    required this.isVisible,
    required this.posOnly,
    required this.wide,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        LdPill(
          isVisible ? (l10n?.visibleInApp ?? 'Visible in app') : (l10n?.hiddenInApp ?? 'Hidden in app'),
          icon: isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          background: isVisible ? Ld.successWash : Ld.ground,
          foreground: isVisible ? Ld.success : Ld.muted,
        ),
        if (posOnly)
          LdPill(l10n?.posOnlyLabel ?? 'POS only',
              icon: Icons.point_of_sale_outlined, background: Ld.warningWash, foreground: Ld.warning),
      ],
    );
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
          child: Row(
            children: [
              const LdIconTile(Icons.category_outlined, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Ld.ink),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: tags),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Ld.ink),
                          ),
                          const SizedBox(height: 6),
                          tags,
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              if (wide) ...[
                const ItemsEditMark(),
                const SizedBox(width: 8),
              ],
              ItemsRowButton(
                icon: Icons.delete_outline_rounded,
                tooltip: l10n?.delete ?? 'Delete',
                danger: true,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
