import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../models/topping.dart';
import '../theme/ld.dart';
import '../utils/money.dart';
import 'manage_items_screen.dart';

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
        SnackBar(content: Text(AppLocalizations.of(context)?.nameIsRequired ?? 'Name is required')),
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
            content: Text(AppLocalizations.of(context)?.toppingSavedSuccessfully ?? 'Topping saved successfully'),
            backgroundColor: Ld.success,
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
            content: Text(AppLocalizations.of(context)?.couldNotSaveToppingPleaseTry ?? 'Could not save topping. Please try again.'),
            backgroundColor: Ld.danger,
          ),
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
        title: widget.isEditing ? widget.topping!.name : (l10n?.addTopping ?? 'Add Topping'),
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
                        labelText: l10n?.toppingName ?? 'Topping Name*',
                        prefixIcon: const Icon(Icons.label_outline, size: 20),
                      ),
                      autofocus: !widget.isEditing,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameLoController,
                      style: const TextStyle(fontSize: 17, color: Ld.ink),
                      decoration: InputDecoration(
                        labelText: l10n?.toppingNameLo ?? 'Lao name (optional)',
                        prefixIcon: const Icon(Icons.translate, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _priceController,
                      style: itemsMoneyInputStyle,
                      decoration: InputDecoration(
                        labelText: l10n?.extraPriceOptional ?? 'Extra Price (Optional)',
                        prefixIcon: itemsKipPrefix,
                        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyInputFormatter()],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ItemsFormCard(
                  children: [
                    DropdownButtonFormField<int?>(
                      // Keep the current group selectable while the list loads.
                      initialValue: _groups.any((g) => g.id == _groupId) ? _groupId : null,
                      key: ValueKey('group-${_groups.length}'),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n?.toppingGroupLabel ?? 'Group',
                        prefixIcon: const Icon(Icons.view_agenda_outlined, size: 20),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            l10n?.toppingNoGroup ?? 'No group (add-on)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final g in _groups)
                          DropdownMenuItem<int?>(
                            value: g.id,
                            child: Text(
                              '${g.displayName} · ${g.isSingleChoice ? (l10n?.toppingPickOne ?? 'Pick 1') : (l10n?.toppingPickMany ?? 'Pick many')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _groupId = v),
                    ),
                    if (_groupId != null) ...[
                      const SizedBox(height: 8),
                      ItemsSwitchRow(
                        icon: Icons.check_circle_outline_rounded,
                        title: l10n?.toppingDefaultLabel ?? 'Selected by default',
                        subtitle: l10n?.toppingDefaultHelp ?? 'Already ticked when the item opens',
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                      ),
                    ],
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
                  label: Text(_isSaving ? 'Saving...' : (l10n?.saveTopping ?? 'Save Topping')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
