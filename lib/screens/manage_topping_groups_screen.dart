import 'package:flutter/material.dart';

import '../models/topping.dart';
import '../services/api_service.dart';
import '../theme/ladolce_pos_ui.dart';
import '../theme/luxury_background.dart';
import '../utils/l10n_ext.dart';

/// Items → Toppings → Topping groups: the headings of the topping picker
/// ("Type", "Taste", "Size"), each pick-one or pick-many, optionally required.
class ManageToppingGroupsScreen extends StatefulWidget {
  const ManageToppingGroupsScreen({super.key});

  @override
  State<ManageToppingGroupsScreen> createState() =>
      _ManageToppingGroupsScreenState();
}

class _ManageToppingGroupsScreenState extends State<ManageToppingGroupsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  List<ToppingGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await _api.fetchToppingGroups(forceRefresh: true);
      groups.sort((a, b) => a.sequence.compareTo(b.sequence));
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _edit([ToppingGroup? group]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _GroupDialog(group: group),
    );
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
      _load();
    }
  }

  Future<void> _delete(ToppingGroup group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteGroup),
        content: Text(ctx.l10n.deleteGroupConfirm(group.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          ElevatedButton(
            style: LaDolcePosUi.primaryButtonStyle(isDestructive: true),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteToppingGroup(group.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.groupDeleted),
          backgroundColor: Colors.orange,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.errorWithMessage(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _summary(BuildContext context, ToppingGroup g) {
    final kind = g.multiple ? context.l10n.pickMany : context.l10n.pickOne;
    return g.required ? '$kind · ${context.l10n.requiredLabel}' : kind;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.toppingGroups),
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
      ),
      body: LuxuryPatternBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(context.l10n.retry),
                        style: LaDolcePosUi.primaryButtonStyle(),
                      ),
                    ],
                  ),
                ),
              )
            : _groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.view_agenda_outlined,
                        size: 48,
                        color: Colors.blueGrey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.noGroupsYet,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.noGroupsYetHint,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: LaDolcePosUi.mutedText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.l10n.addGroup),
                        style: LaDolcePosUi.primaryButtonStyle(),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                itemCount: _groups.length,
                itemBuilder: (context, i) {
                  final g = _groups[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LaDolcePosUi.radius),
                      side: const BorderSide(color: LaDolcePosUi.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                      onTap: () => _edit(g),
                      leading: const Icon(
                        Icons.view_agenda_outlined,
                        color: LaDolcePosUi.navy,
                      ),
                      title: Text(
                        g.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(_summary(context, g)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.red.withValues(alpha: 0.7),
                        tooltip: context.l10n.deleteGroup,
                        onPressed: () => _delete(g),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: LaDolcePosUi.navy,
        foregroundColor: Colors.white,
        tooltip: context.l10n.addGroup,
        onPressed: () => _edit(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _GroupDialog extends StatefulWidget {
  final ToppingGroup? group;

  const _GroupDialog({this.group});

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final ApiService _api = ApiService();
  late final TextEditingController _name = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late final TextEditingController _nameLo = TextEditingController(
    text: (widget.group?.nameLo ?? '') == (widget.group?.name ?? '')
        ? ''
        : widget.group!.nameLo,
  );
  late bool _multiple = widget.group?.multiple ?? false;
  late bool _required = widget.group?.required ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nameLo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.nameIsRequired)));
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.saveToppingGroup(
        id: widget.group?.id,
        name: name,
        nameLo: _nameLo.text.trim(),
        multiple: _multiple,
        required: _required,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.couldNotSaveGroup(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.group?.displayName ?? l10n.addGroup),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.group == null,
              decoration: LaDolcePosUi.input(
                hintText: l10n.groupNameHint,
                prefixIcon: const Icon(Icons.label_outline, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameLo,
              decoration: LaDolcePosUi.input(
                hintText: l10n.laoNameOptional,
                prefixIcon: const Icon(Icons.translate, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: _multiple,
              onChanged: (v) => setState(() => _multiple = v ?? false),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.pickOne),
                    subtitle: Text(l10n.pickOneHint),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.pickMany),
                    subtitle: Text(l10n.pickManyHint),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: _required,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: LaDolcePosUi.navy,
              title: Text(l10n.requiredLabel),
              subtitle: Text(l10n.requiredHint),
              onChanged: (v) => setState(() => _required = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: LaDolcePosUi.primaryButtonStyle(),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
