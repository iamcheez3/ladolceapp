import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import 'manage_items_screen.dart';

class CategoryEditScreen extends StatefulWidget {
  final Map<String, dynamic>? category;
  final List<dynamic> categories;

  const CategoryEditScreen({
    super.key,
    this.category,
    required this.categories,
  });

  bool get isEditing => category != null;

  @override
  State<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _nameController;
  late bool _showInApp;
  late bool _hideInSelfOrder;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?['name'] ?? '');
    _showInApp = widget.category?['pos_show_in_app'] ?? true;
    _hideInSelfOrder = widget.category?['hide_in_self_order'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.nameIsRequired ?? 'Name is required')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _apiService.saveCategory(
        id: widget.category?['id'],
        name: name,
        showInApp: _showInApp,
        hideInSelfOrder: _hideInSelfOrder,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? (AppLocalizations.of(context)?.categoryUpdatedSuccessfully ?? 'Category updated successfully')
                : (AppLocalizations.of(context)?.categoryAddedSuccessfully ?? 'Category added successfully')),
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
    final gutter = itemsGutter(context);
    return Scaffold(
      appBar: LdHeader(
        title: widget.isEditing ? widget.category!['name'] : (l10n?.addCategory ?? 'Add Category'),
        actions: [
          ItemsHeaderAction(
            label: l10n?.save ?? 'Save',
            icon: Icons.check_rounded,
            busy: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40 + Ld.navInset(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ItemsFormCard(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(fontSize: 17, color: Ld.ink),
                      decoration: InputDecoration(
                        labelText: l10n?.categoryName ?? 'Category Name*',
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 12),
                    ItemsSwitchRow(
                      icon: _showInApp ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      title: l10n?.showInApp ?? 'Show in app',
                      subtitle: l10n?.onlyCheckedCategoriesAreVisibleIn ?? 'Only checked categories are visible in POS app.',
                      value: _showInApp,
                      onChanged: (v) => setState(() => _showInApp = v),
                    ),
                    const Divider(height: 1, indent: 56),
                    // POS only: cashiers see it, customers in self-order do not.
                    ItemsSwitchRow(
                      icon: _hideInSelfOrder ? Icons.point_of_sale_outlined : Icons.storefront_outlined,
                      title: l10n?.posOnlyLabel ?? 'POS only',
                      subtitle: l10n?.posOnlyCategoryHelp ??
                          'Hidden in the customer self-order app; cashiers still see it.',
                      value: _hideInSelfOrder,
                      onChanged: (v) => setState(() => _hideInSelfOrder = v),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(_isSaving ? 'Saving...' : (l10n?.saveCategory ?? 'Save Category')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
