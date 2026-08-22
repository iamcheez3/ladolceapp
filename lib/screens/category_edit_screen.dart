import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

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
  bool _isSaving = false;

  static const Color _accent = Colors.blue;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?['name'] ?? '');
    _showInApp = widget.category?['pos_show_in_app'] ?? true;
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
        SnackBar(content: Text(AppLocalizations.of(context)?.nameIsRequired ?? (AppLocalizations.of(context)?.nameIsRequired ?? 'Name is required'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _apiService.saveCategory(
        id: widget.category?['id'],
        name: name,
        showInApp: _showInApp,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? (AppLocalizations.of(context)?.categoryUpdatedSuccessfully ?? 'Category updated successfully')
                : (AppLocalizations.of(context)?.categoryAddedSuccessfully ?? 'Category added successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
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
        title: Text(widget.isEditing ? widget.category!['name'] : (AppLocalizations.of(context)?.addCategory ?? 'Add Category')),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(AppLocalizations.of(context)?.save ?? (AppLocalizations.of(context)?.save ?? 'Save'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
      body: LuxuryPatternBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.categoryName ?? (AppLocalizations.of(context)?.categoryName ?? 'Category Name*'),
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(LaDolcePosUi.radiusSm),
                        border: Border.all(color: _accent.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showInApp ? Icons.visibility : Icons.visibility_off,
                            color: _showInApp ? Colors.green : LaDolcePosUi.mutedText,
                            size: 22,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.of(context)?.showInApp ?? (AppLocalizations.of(context)?.showInApp ?? 'Show in app'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _showInApp ? LaDolcePosUi.text : LaDolcePosUi.mutedText,
                                  ),
                                ),
                                Text(AppLocalizations.of(context)?.onlyCheckedCategoriesAreVisibleIn ?? (AppLocalizations.of(context)?.onlyCheckedCategoriesAreVisibleIn ?? 'Only checked categories are visible in POS app.'),
                                  style: TextStyle(fontSize: 12, color: LaDolcePosUi.mutedText),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _showInApp,
                            activeColor: _accent,
                            onChanged: (v) => setState(() => _showInApp = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isSaving ? 'Saving...' : (AppLocalizations.of(context)?.saveCategory ?? 'Save Category')),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
