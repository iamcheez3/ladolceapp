import 'package:flutter/material.dart';
import 'package:ladolce/l10n/app_localizations.dart';

import '../models/topping.dart';
import '../services/api_service.dart';
import '../theme/ld.dart';
import 'manage_items_screen.dart';

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
                  decoration: InputDecoration(
                    labelText: l10n?.toppingGroupName ?? 'Group name (e.g. Size)*',
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameLoCtrl,
                  decoration: InputDecoration(
                    labelText: l10n?.toppingGroupNameLo ?? 'Lao name (optional)',
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
              style: ElevatedButton.styleFrom(minimumSize: const Size(88, 48)),
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
          backgroundColor: Ld.success,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.toppingGroupSaveFailed(e.toString()) ?? 'Could not save group: $e'),
          backgroundColor: Ld.danger,
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
            style: itemsDangerButtonStyle(),
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
          backgroundColor: Ld.warning,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Ld.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: LdHeader(
        title: l10n?.toppingGroups ?? 'Topping groups',
        subtitle: l10n?.toppingGroupsSubtitle,
        actions: [
          ItemsHeaderAction(
            label: l10n?.addToppingGroup ?? 'Add group',
            icon: Icons.add_rounded,
            onPressed: () => _edit(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Ld.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        tooltip: l10n?.addToppingGroup ?? 'Add group',
        onPressed: () => _edit(),
        child: const Icon(Icons.add_rounded),
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
                  onAction: _load,
                )
              : _groups.isEmpty
                  ? ItemsStateView(
                      icon: Icons.view_agenda_outlined,
                      title: l10n?.noToppingGroupsYet ?? 'No groups yet',
                      message: l10n?.noToppingGroupsHelp ??
                          'Groups put toppings under headings like Type (Hot / Iced), Taste or Size (M / L).',
                      actionLabel: l10n?.addToppingGroup ?? 'Add group',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _edit(),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final gutter = itemsGutter(context);
                          const gap = 14.0;
                          final inner = box.maxWidth - gutter * 2;
                          final columns = (inner / 300).floor().clamp(1, 4);
                          final w = (inner - gap * (columns - 1)) / columns;
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 96 + Ld.navInset(context)),
                            child: Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final g in _groups)
                                  SizedBox(
                                    width: w,
                                    child: _GroupCard(
                                      group: g,
                                      onTap: () => _edit(group: g),
                                      onDelete: () => _delete(g),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ToppingGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _GroupCard({required this.group, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final g = group;
    final lao = (g.nameLo ?? '').trim();
    return Material(
      color: Ld.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ld.rXl),
        side: const BorderSide(color: Ld.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ld.rXl)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Ld.title(19),
                    ),
                    if (lao.isNotEmpty && g.nameLo != g.name)
                      Text(lao, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ld.small),
                    const SizedBox(height: 10),
                    // Rule pills, e.g. "Pick 1" and "Required".
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        LdPill(g.isSingleChoice
                            ? (l10n?.toppingPickOne ?? 'Pick 1')
                            : (l10n?.toppingPickMany ?? 'Pick many')),
                        if (g.required)
                          LdPill(l10n?.toppingRequired ?? 'Required',
                              background: Ld.dangerWash, foreground: Ld.danger),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
