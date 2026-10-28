import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import '../models/topping.dart';
import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';

/// Items → Toppings → Topping groups: the headings of the topping picker
/// ("Type", "Taste", "Size"), each pick-one or pick-many, optionally required.
/// Options are put into a group from the topping's own edit screen.
class ManageToppingGroupsScreen extends StatefulWidget {
  const ManageToppingGroupsScreen({super.key});

  @override
  State<ManageToppingGroupsScreen> createState() => _ManageToppingGroupsScreenState();
}

class _ManageToppingGroupsScreenState extends State<ManageToppingGroupsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<ToppingGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final groups = await _apiService.fetchToppingGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
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

  Future<void> _edit({ToppingGroup? group}) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: group?.name ?? '');
    final lao = (group?.nameLo ?? '').trim();
    final nameLoCtrl = TextEditingController(text: lao == group?.name ? '' : lao);
    var single = group?.isSingleChoice ?? true;
    var required = group?.required ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(group == null
              ? (l10n?.addToppingGroup ?? 'Add group')
              : group.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: group == null,
                  decoration: LaDolcePosUi.input(
                    hintText: l10n?.toppingGroupName ?? 'Group name (e.g. Size)*',
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameLoCtrl,
                  decoration: LaDolcePosUi.input(
                    hintText: l10n?.toppingGroupNameLo ?? 'Lao name (optional)',
                    prefixIcon: const Icon(Icons.translate, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                RadioGroup<bool>(
                  groupValue: single,
                  onChanged: (v) => setDialogState(() => single = v ?? true),
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        title: Text(l10n?.toppingPickOne ?? 'Pick 1'),
                        subtitle: Text(l10n?.toppingPickOneHelp ?? 'Pick one, e.g. Hot / Iced / Frappe'),
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        title: Text(l10n?.toppingPickMany ?? 'Pick many'),
                        subtitle: Text(l10n?.toppingPickManyHelp ?? 'Pick many, e.g. extra shot + oat milk'),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: required,
                  activeThumbColor: LaDolcePosUi.navy,
                  title: Text(l10n?.toppingRequired ?? 'Required'),
                  subtitle: Text(l10n?.toppingRequiredHelp ?? 'An option must be chosen before adding the item'),
                  onChanged: (v) => setDialogState(() => required = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            ElevatedButton(
              style: LaDolcePosUi.primaryButtonStyle(),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.nameIsRequired ?? 'Name is required')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(l10n?.save ?? 'Save'),
            ),
          ],
        ),
      ),
    );

    // Controllers are not disposed here: the dialog's fields still use them
    // during its closing animation.
    final name = nameCtrl.text.trim();
    final nameLo = nameLoCtrl.text.trim();
    if (saved != true || !mounted) return;

    try {
      await _apiService.saveToppingGroup(
        id: group?.id,
        name: name,
        nameLo: nameLo,
        single: single,
        required: required,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.toppingGroupSaved ?? 'Group saved'),
          backgroundColor: Colors.green,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.toppingGroupSaveFailed(e.toString()) ?? 'Could not save group: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _delete(ToppingGroup group) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteToppingGroup ?? 'Delete group'),
        content: Text(l10n?.deleteToppingGroupConfirm ??
            'Delete this group? Its toppings stay, as plain add-ons.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            style: LaDolcePosUi.primaryButtonStyle(isDestructive: true),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n?.delete ?? 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _apiService.deleteToppingGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.toppingGroupDeleted ?? 'Group deleted'),
          backgroundColor: Colors.orange,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.toppingGroups ?? 'Topping groups'),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        tooltip: l10n?.addToppingGroup ?? 'Add group',
        onPressed: () => _edit(),
        child: const Icon(Icons.add_rounded),
      ),
      body: LuxuryPatternBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(l10n?.retry ?? 'Retry'),
                            style: LaDolcePosUi.primaryButtonStyle(),
                          ),
                        ],
                      ),
                    ),
                  )
                : _groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.view_agenda_outlined,
                                  size: 48, color: LaDolcePosUi.mutedText),
                              const SizedBox(height: 16),
                              Text(l10n?.noToppingGroupsYet ?? 'No groups yet',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text(
                                l10n?.noToppingGroupsHelp ??
                                    'Groups put toppings under headings like Type (Hot / Iced), Taste or Size (M / L).',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: LaDolcePosUi.mutedText),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () => _edit(),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(l10n?.addToppingGroup ?? 'Add group'),
                                style: LaDolcePosUi.primaryButtonStyle(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        children: [
                          for (final g in _groups)
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                                side: const BorderSide(color: LaDolcePosUi.border),
                              ),
                              child: ListTile(
                                onTap: () => _edit(group: g),
                                leading: const Icon(Icons.view_agenda_outlined,
                                    color: LaDolcePosUi.navy),
                                title: Text(
                                  g.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text([
                                  if ((g.nameLo ?? '').trim().isNotEmpty && g.nameLo != g.name) g.nameLo!,
                                  g.isSingleChoice
                                      ? (l10n?.toppingPickOne ?? 'Pick 1')
                                      : (l10n?.toppingPickMany ?? 'Pick many'),
                                  if (g.required) l10n?.toppingRequired ?? 'Required',
                                ].join(' · ')),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  color: Colors.red.withValues(alpha: 0.7),
                                  tooltip: l10n?.delete ?? 'Delete',
                                  onPressed: () => _delete(g),
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}
