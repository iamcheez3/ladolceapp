import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../utils/l10n_ext.dart';

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
  bool _groupsLoaded = false;
  int? _groupId;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final t = widget.topping;
    _nameController = TextEditingController(text: t?.name ?? '');
    // The backend echoes the English name when no Lao name is saved.
    _nameLoController = TextEditingController(
      text: (t == null || t.nameLo == t.name) ? '' : t.nameLo,
    );
    _priceController = TextEditingController(
      text: t != null ? t.extraPrice.toStringAsFixed(0) : '',
    );
    _groupId = t?.groupId;
    _isDefault = t?.isDefault ?? false;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _apiService.fetchToppingGroups(forceRefresh: true);
      groups.sort((a, b) => a.sequence.compareTo(b.sequence));
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _groupsLoaded = true;
        if (_groupId != null && !groups.any((g) => g.id == _groupId)) {
          _groupId = null;
        }
      });
    } catch (_) {
      // Without groups the topping can still be saved as a plain add-on.
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
    final price = double.tryParse(priceStr) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.nameIsRequired)));
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _apiService.saveTopping(
        id: widget.topping?.id,
        name: name,
        nameLo: _nameLoController.text.trim(),
        extraPrice: price,
        groupId: _groupId,
        isDefault: _isDefault,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.toppingSavedSuccessfully),
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
          SnackBar(
            content: Text(context.l10n.couldNotSaveToppingPleaseTry),
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
        title: Text(
          widget.isEditing ? widget.topping!.name : context.l10n.addTopping,
        ),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                context.l10n.save,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
                        hintText: context.l10n.toppingName,
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameLoController,
                      decoration: LaDolcePosUi.input(
                        hintText: context.l10n.laoNameOptional,
                        prefixIcon: const Icon(Icons.translate, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _priceController,
                      decoration: LaDolcePosUi.input(
                        hintText: context.l10n.extraPriceOptional,
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '₭',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                  children: [
                    DropdownButtonFormField<int?>(
                      // Starts again once the groups arrive, from the group
                      // checked against them.
                      key: ValueKey(_groupsLoaded),
                      initialValue: _groupId,
                      isExpanded: true,
                      decoration: LaDolcePosUi.input(
                        hintText: context.l10n.toppingGroups,
                        prefixIcon: const Icon(
                          Icons.view_agenda_outlined,
                          size: 20,
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(context.l10n.noGroupAddOn),
                        ),
                        for (final g in _groups)
                          DropdownMenuItem<int?>(
                            value: g.id,
                            child: Text(g.displayName),
                          ),
                        // The topping's own group until the list has loaded
                        // (or if it fails to): a value without an item is an
                        // error.
                        if (_groupId != null &&
                            !_groups.any((g) => g.id == _groupId))
                          DropdownMenuItem<int?>(
                            value: _groupId,
                            child: Text(widget.topping?.groupDisplayName ?? ''),
                          ),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                    if (_groupId != null)
                      SwitchListTile(
                        value: _isDefault,
                        contentPadding: const EdgeInsets.only(top: 8),
                        activeThumbColor: LaDolcePosUi.navy,
                        title: Text(context.l10n.selectedByDefault),
                        subtitle: Text(context.l10n.selectedByDefaultHint),
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
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_isSaving ? 'Saving...' : context.l10n.saveTopping),
                style: LaDolcePosUi.primaryButtonStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
