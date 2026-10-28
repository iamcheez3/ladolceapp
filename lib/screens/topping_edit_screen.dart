import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../utils/money.dart';

class ToppingEditScreen extends StatefulWidget {
  final Topping? topping;

  const ToppingEditScreen({super.key, this.topping});

  bool get isEditing => topping != null;

  @override
  State<ToppingEditScreen> createState() => _ToppingEditScreenState();
}

class _ToppingEditScreenState extends State<ToppingEditScreen> {
  final ApiService _apiService = ApiService();
  late final TextEditingController _nameController;
  late final TextEditingController _nameLoController;
  late final TextEditingController _priceController;
  bool _isSaving = false;
  List<ToppingGroup> _groups = [];
  int? _groupId;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final t = widget.topping;
    _nameController = TextEditingController(text: t?.name ?? '');
    // The server fills name_lo with the English name when it is blank.
    final lao = (t?.nameLo ?? '').trim();
    _nameLoController = TextEditingController(text: lao == t?.name ? '' : lao);
    _priceController = TextEditingController(
      text: t != null && t.extraPrice > 0 ? money(t.extraPrice) : '',
    );
    _groupId = t?.groupId;
    _isDefault = t?.isDefault ?? false;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _apiService.fetchToppingGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      debugPrint('[ToppingEdit] groups not loaded: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameLoController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.trim();
    final price = parseMoney(priceStr);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)?.nameIsRequired ?? (AppLocalizations.of(context)?.nameIsRequired ?? 'Name is required'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _apiService.addTopping(
        name,
        price,
        id: widget.topping?.id,
        nameLo: _nameLoController.text.trim(),
        groupId: _groupId,
        isDefault: _groupId != null && _isDefault,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.toppingSavedSuccessfully ?? (AppLocalizations.of(context)?.toppingSavedSuccessfully ?? 'Topping saved successfully')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('[ToppingEdit] save failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.couldNotSaveToppingPleaseTry ?? (AppLocalizations.of(context)?.couldNotSaveToppingPleaseTry ?? 'Could not save topping. Please try again.')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? widget.topping!.name : (AppLocalizations.of(context)?.addTopping ?? 'Add Topping')),
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
                        hintText: AppLocalizations.of(context)?.toppingName ?? (AppLocalizations.of(context)?.toppingName ?? 'Topping Name*'),
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameLoController,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.toppingNameLo ?? 'Lao name (optional)',
                        prefixIcon: const Icon(Icons.translate, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _priceController,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.extraPriceOptional ?? (AppLocalizations.of(context)?.extraPriceOptional ?? 'Extra Price (Optional)'),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('₭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LaDolcePosUi.card,
                  borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                  border: Border.all(color: LaDolcePosUi.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int?>(
                      // Keep the current group selectable while the list loads.
                      initialValue: _groups.any((g) => g.id == _groupId) ? _groupId : null,
                      key: ValueKey('group-${_groups.length}'),
                      isExpanded: true,
                      decoration: LaDolcePosUi.input(
                        hintText: AppLocalizations.of(context)?.toppingGroupLabel ?? 'Group',
                        prefixIcon: const Icon(Icons.view_agenda_outlined, size: 20),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(AppLocalizations.of(context)?.toppingNoGroup ?? 'No group (add-on)'),
                        ),
                        for (final g in _groups)
                          DropdownMenuItem<int?>(
                            value: g.id,
                            child: Text(
                              '${g.displayName} · ${g.isSingleChoice ? (AppLocalizations.of(context)?.toppingPickOne ?? 'Pick 1') : (AppLocalizations.of(context)?.toppingPickMany ?? 'Pick many')}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                    if (_groupId != null)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isDefault,
                        activeThumbColor: LaDolcePosUi.navy,
                        title: Text(AppLocalizations.of(context)?.toppingDefaultLabel ?? 'Selected by default'),
                        subtitle: Text(AppLocalizations.of(context)?.toppingDefaultHelp ?? 'Already ticked when the item opens'),
                        onChanged: (v) => setState(() => _isDefault = v),
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
                label: Text(_isSaving ? 'Saving...' : (AppLocalizations.of(context)?.saveTopping ?? 'Save Topping')),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
